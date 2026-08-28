#!/usr/bin/env Rscript
## Scrape the FULL text of every fertility-relevant Nairaland Family thread —
## all pages of each thread, not just the first.
##
## Nairaland sits behind Cloudflare, so requests must come from a real browser
## session: {chromote} launches Chrome, the challenge clears automatically on
## the first page load, and every request thereafter is a lightweight fetch()
## injected into that page (HTML only — no images/ads), parsed in R with rvest.
##
## Politeness: ~1 request/second with jitter; HTTP 429 -> 5s backoff, 3 tries.
## Checkpointing: posts append to data/raw/threads_fulltext.jsonl as each
## thread completes, and finished thread ids go to a ledger file — rerunning
## the script resumes where it stopped.
##
## Usage:  Rscript code/scraping/4_scrape_threads.R  (from the repo root)
## Output: data/raw/threads_fulltext.jsonl   (one JSON per post:
##         tid, page, k, author, op, time, date, text)

## Library packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, chromote, rvest, jsonlite, progress, here)

posts_per_page <- 32          # Nairaland pagination

out_file <- here("data", "nairaland", "raw", "threads_fulltext.jsonl")
ledger_file <- here("data", "nairaland", "raw", "threads_fulltext_done.txt")
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
if (exists("ledger_file")) dir.create(dirname(ledger_file), recursive = TRUE, showWarnings = FALSE)

## ---- 1. target threads: the topics we picked ---------------------------------
## all fertility-core (family size + childbearing + family planning) and
## parenting-cost threads, plus the most-viewed polygyny and women's-work
## threads (same selection as the original deep scrape)
threads <- read_csv(here("data", "nairaland", "prep", "threads_dated.csv"),
                    show_col_types = FALSE)

targets <- threads %>%
  filter(fertility_core | d_parenting_cost == 1) %>%
  bind_rows(threads %>% filter(d_polygyny == 1) %>% slice_max(n_views, n = 60),
            threads %>% filter(d_womens_work_autonomy == 1) %>% slice_max(n_views, n = 60)) %>%
  distinct(thread_id, .keep_all = TRUE) %>%
  mutate(n_pages = pmax(ceiling(coalesce(n_posts, 1) / posts_per_page), 1)) %>%
  select(thread_id, n_pages)

done <- if (file.exists(ledger_file)) as.integer(read_lines(ledger_file)) else integer()
todo <- targets %>% filter(!thread_id %in% done)

cat(sprintf("threads: %d selected, %d already done, %d to scrape (~%d page fetches)\n",
            nrow(targets), length(done), nrow(todo), sum(todo$n_pages)))

## ---- 2. browser session ------------------------------------------------------
## Default: headless Chrome. If Cloudflare refuses to clear headless (common),
## launch a VISIBLE Chrome with a debugging port and attach to it instead:
##   Terminal:
##     /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
##       --remote-debugging-port=9222 --user-data-dir=/tmp/chromote-profile \
##       https://www.nairaland.com/family
##   (a separate --user-data-dir is required if Chrome is already running)
##   Then run this script with:  CHROMOTE_PORT=9222 Rscript ...
chromote_port <- Sys.getenv("CHROMOTE_PORT", "")
b <- if (nzchar(chromote_port)) {
  ChromoteSession$new(parent = Chromote$new(
    browser = ChromeRemote$new(host = "localhost", port = as.integer(chromote_port))))
} else {
  ChromoteSession$new()
}
b$Page$navigate("https://www.nairaland.com/family")

## wait for Cloudflare's automatic check to clear (no CAPTCHA involved)
wait_for_clearance <- function(session, timeout_s = 60) {
  t0 <- Sys.time()
  cat("waiting for Cloudflare check to clear (up to", timeout_s, "s)...\n")
  repeat {
    Sys.sleep(2)
    title <- session$Runtime$evaluate("document.title")$result$value
    if (!str_detect(title, "Just a moment")) return(invisible(TRUE))
    if (difftime(Sys.time(), t0, units = "secs") > timeout_s)
      stop("Cloudflare did not clear in headless Chrome. Launch a VISIBLE ",
           "Chrome and attach to it:\n",
           "  1) Terminal: /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome ",
           "--remote-debugging-port=9222 --user-data-dir=/tmp/chromote-profile ",
           "https://www.nairaland.com/family\n",
           "  2) wait until the forum renders in that window\n",
           "  3) rerun with: CHROMOTE_PORT=9222 (env var), or in an interactive ",
           "session: b <- ChromoteSession$new(parent = Chromote$new(browser = ",
           "ChromeRemote$new(host = 'localhost', port = 9222)))")
  }
}
wait_for_clearance(b)
cat("browser session cleared\n")

## fetch one URL through the page's session; returns HTML or NA
fetch_html <- function(session, path, tries = 3) {
  js <- sprintf(
    "fetch('%s', {credentials: 'include'}).then(r => r.status === 200 ? r.text() : '__HTTP_' + r.status)",
    path)
  for (attempt in seq_len(tries)) {
    res <- tryCatch(
      session$Runtime$evaluate(js, awaitPromise = TRUE, returnByValue = TRUE,
                               timeout_ = 30000)$result$value,
      error = function(e) NA_character_)
    if (is.na(res)) { Sys.sleep(4); next }
    if (res == "__HTTP_429") { Sys.sleep(5); next }      # rate-limited: back off
    if (str_starts(res, "__HTTP_")) return(NA_character_) # 404 etc.: give up
    return(res)
  }
  NA_character_
}

## ---- 3. parse a thread page --------------------------------------------------
parse_thread_page <- function(html, tid, page) {
  doc <- read_html(html)
  heads <- html_elements(doc, "td.bold.l.pu")   # post headers
  bodies <- html_elements(doc, "td.l.w.pd")     # post bodies
  n <- min(length(heads), length(bodies))
  if (n == 0) return(NULL)
  map_dfr(seq_len(n), function(k) {
    h <- heads[[k]] %>% html_text2() %>% str_replace_all("\\s+", " ")
    ## "Title by Author(op): 2:19pm On May 28, 2019" (no year = current year)
    hm <- str_match(h, "by ([^:]+):\\s*([\\d:apm]+)(?: On (.+))?$")
    body <- bodies[[k]]
    ## drop share widgets and quoted text before extracting
    xml2::xml_remove(html_elements(body, ".s, script, style, blockquote"))
    tibble(tid = tid, page = page, k = k - 1L,
           author = if (!is.na(hm[2])) str_trim(str_remove(hm[2], fixed("(op)"))) else NA,
           op = str_detect(h, fixed("(op)")),
           time = hm[3], date = hm[4],
           text = body %>% html_text2() %>% str_replace_all("\\s+", " ") %>%
             str_trim() %>% str_sub(1, 4000))
  })
}

## ---- 4. main loop with progress bar ------------------------------------------
pb <- progress_bar$new(
  total = sum(todo$n_pages),
  format = "scraping [:bar] :current/:total pages (:percent) | thread :what | eta :eta",
  clear = FALSE, width = 90)

for (i in seq_len(nrow(todo))) {
  tid <- todo$thread_id[i]
  thread_posts <- list()
  for (p in seq_len(todo$n_pages[i]) - 1L) {          # pages are 0-indexed
    pb$tick(tokens = list(what = tid))
    html <- fetch_html(b, sprintf("/%d/x/%d", tid, p))
    if (is.na(html)) break
    posts <- parse_thread_page(html, tid, p)
    if (is.null(posts)) break                          # past the last page
    thread_posts[[length(thread_posts) + 1]] <- posts
    Sys.sleep(runif(1, 0.9, 1.3))                      # polite pacing
  }
  ## checkpoint: write the thread's posts, then mark it done
  if (length(thread_posts) > 0) {
    bind_rows(thread_posts) %>%
      pmap_chr(function(...) toJSON(list(...), auto_unbox = TRUE, null = "null")) %>%
      write_lines(out_file, append = TRUE)
  }
  write_lines(tid, ledger_file, append = TRUE)
}

b$close()
cat(sprintf("\ndone: %s\n", out_file))
