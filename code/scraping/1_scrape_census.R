#!/usr/bin/env Rscript
## Census of the Nairaland Family board: scrape every listing page and record
## each thread's id, title, creator, post count, and view count. This is the
## sampling frame processed by 3_classify_and_date.R and scraped by 4_scrape_threads.R.
##
## Same session mechanics as 4_scrape_threads.R: {chromote} holds a
## Cloudflare-cleared browser session; requests are lightweight fetch() calls;
## ~1 request/second; checkpointed per listing page so reruns resume.
##
## Usage:  Rscript code/scraping/1_scrape_census.R          (headless)
##         CHROMOTE_PORT=9222 Rscript code/scraping/...            (attach to a
##         visible Chrome started with --remote-debugging-port=9222)
## Output: data/nairaland/family_listings.jsonl  (one JSON per thread:
##         i=id, t=title, a=creator, p=posts, v=views, pg=listing page)

## Library packages
pacman::p_load(tidyverse, 
               chromote, 
               rvest,
               jsonlite,
               progress,
               here)

out_file <- here("data", "nairaland", "raw", "family_listings.jsonl")
ledger_file <- here("data", "nairaland", "raw", "census_pages_done.txt")
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
if (exists("ledger_file")) dir.create(dirname(ledger_file), recursive = TRUE, showWarnings = FALSE)


## Frame protection: the census APPENDS (that is how checkpointed resume works),
## so a fresh run must not write into an existing frame from another date.
fresh_run <- !file.exists(ledger_file) || length(read_lines(ledger_file)) == 0
if (fresh_run && file.exists(out_file))
  stop("data/nairaland/family_listings.jsonl already exists (the archived ",
       "August 2026 frame). To collect a NEW census, move that file aside ",
       "first, e.g.:\n  mv data/nairaland/family_listings.jsonl ",
       "data/nairaland/family_listings_2026-08-06.jsonl\n",
       "Appending a new crawl onto an old frame would mix collection dates.")

## ---- 1. browser session (same helpers as 4_scrape_threads.R) --------------
chromote_port <- Sys.getenv("CHROMOTE_PORT", "")
b <- if (nzchar(chromote_port)) {
  ChromoteSession$new(parent = Chromote$new(
    browser = ChromeRemote$new(host = "localhost", port = as.integer(chromote_port))))
} else {
  ChromoteSession$new()
}
b$Page$navigate("https://www.nairaland.com/family")

wait_for_clearance <- function(session, timeout_s = 60) {
  t0 <- Sys.time()
  cat("waiting for Cloudflare check to clear (up to", timeout_s, "s)...\n")
  repeat {
    Sys.sleep(2)
    title <- session$Runtime$evaluate("document.title")$result$value
    if (!str_detect(title, "Just a moment")) return(invisible(TRUE))
    if (difftime(Sys.time(), t0, units = "secs") > timeout_s)
      stop("Cloudflare did not clear headless; start a visible Chrome with ",
           "--remote-debugging-port=9222 --user-data-dir=/tmp/chromote-profile ",
           "and rerun with CHROMOTE_PORT=9222.")
  }
}
wait_for_clearance(b)
cat("browser session cleared\n")

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
    if (res == "__HTTP_429") { Sys.sleep(5); next }
    if (str_starts(res, "__HTTP_")) return(NA_character_)
    return(res)
  }
  NA_character_
}

## ---- 2. how many listing pages? ------------------------------------------------
first <- fetch_html(b, "/family")
n_pages <- read_html(first) %>%
  html_text2() %>%
  str_match("of (\\d+) pages") %>%
  .[, 2] %>%
  as.integer()
cat("listing pages:", n_pages, "\n")

done <- if (file.exists(ledger_file)) as.integer(read_lines(ledger_file)) else integer()
todo <- setdiff(seq_len(n_pages) - 1L, done)   # pages are 0-indexed

## ---- 3. parse one listing page --------------------------------------------------
parse_listing <- function(html, page_no) {
  doc <- read_html(html)
  cells <- html_elements(doc, "td[id]")
  map_dfr(cells, function(td) {
    a <- html_element(td, "a[href^='/']")
    if (is.na(a)) return(NULL)
    m <- str_match(html_attr(a, "href"), "^/(\\d+)/")
    if (is.na(m[2])) return(NULL)
    meta <- td %>% html_text2() %>% str_replace_all("\\s+", " ")
    mm <- str_match(meta, "Created by ([^.]+)\\. ([\\d,]+) posts\\. ([\\d,]+) views")
    tibble(i = as.integer(m[2]), t = html_text2(a), pg = page_no,
           a = mm[2],
           p = as.integer(str_remove_all(mm[3], ",")),
           v = as.integer(str_remove_all(mm[4], ",")))
  })
}

## ---- 4. main loop with progress bar ---------------------------------------------
pb <- progress_bar$new(
  total = length(todo),
  format = "census [:bar] :current/:total pages (:percent) | eta :eta",
  clear = FALSE, width = 80)

for (n in todo) {
  pb$tick()
  html <- fetch_html(b, paste0("/family/", n))
  if (!is.na(html)) {
    rows <- parse_listing(html, n)
    if (nrow(rows) > 0) {
      rows %>%
        pmap_chr(function(...) toJSON(list(...), auto_unbox = TRUE, null = "null")) %>%
        write_lines(out_file, append = TRUE)
    }
  }
  write_lines(n, ledger_file, append = TRUE)
  Sys.sleep(runif(1, 0.9, 1.3))
}

b$close()
cat(sprintf("\ndone: %s (dedupe on i when reading — threads can move between pages mid-crawl)\n",
            out_file))
