#!/usr/bin/env Rscript
## OPTIONAL -- Calibration sample for dating threads: fetch the FIRST post of ~75 threads
## sampled across Nairaland's full thread-ID range and record its timestamp.
## Thread IDs are assigned sequentially site-wide, so these (id, date) pairs
## let 10_nairaland_data_prep.Rmd interpolate a creation date for every thread. 
## This just gives us another option for us to timestamps that we can compare. 
##
## Same session mechanics as the other scrapers: {chromote} holds a
## Cloudflare-cleared browser session; ~1 request/second; deleted thread ids
## fall forward to nearby ids.
##
## Usage:  Rscript code/scraping/2_scrape_calibration.R           (headless)
##         CHROMOTE_PORT=9222 Rscript code/scraping/...           (attach to a
##         visible Chrome started with --remote-debugging-port=9222)
## Output: data/nairaland/calibration.jsonl  (one JSON per sampled thread:
##         i=thread id, d=first-post date "May 28, 2019" (null = current year),
##         t=first-post time)

## Library packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, chromote, rvest, jsonlite, progress, here)

out_file <- here("data", "nairaland", "raw", "calibration.jsonl")
n_points <- 75
id_min <- 2000        # earliest surviving threads (2005)
id_max <- 8.72e6      # current top of the ID range at collection (Aug 2026)
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)

## ---- 1. browser session --------------------------------------------------------
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

## ---- 2. first-post timestamp of one thread -------------------------------------
first_post_stamp <- function(html) {
  heads <- read_html(html) %>% html_elements("td.bold.l.pu")
  if (length(heads) == 0) return(NULL)
  h <- heads[[1]] %>% html_text2() %>% str_replace_all("\\s+", " ")
  ## "Title by Author(op): 2:19pm On May 28, 2019" (no year = current year)
  hm <- str_match(h, "by ([^:]+):\\s*([\\d:apm]+)(?: On (.+))?$")
  if (is.na(hm[3])) return(NULL)
  list(t = hm[3], d = if (is.na(hm[4])) NULL else str_trim(hm[4]))
}

## ---- 3. sample IDs geometrically and fetch --------------------------------------
sample_ids <- unique(round(exp(seq(log(id_min), log(id_max), length.out = n_points))))
pb <- progress_bar$new(
  total = length(sample_ids),
  format = "calibration [:bar] :current/:total (:percent) | eta :eta",
  clear = FALSE, width = 80)

for (id0 in sample_ids) {
  pb$tick()
  ## deleted threads: step forward to a nearby surviving id
  for (off in c(0:4, seq(5, 40, by = 7))) {
    html <- fetch_html(b, sprintf("/%d/x", id0 + off))
    if (!is.na(html)) {
      stamp <- first_post_stamp(html)
      if (!is.null(stamp)) {
        toJSON(list(i = id0 + off, d = stamp$d, t = stamp$t),
               auto_unbox = TRUE, null = "null") %>%
          write_lines(out_file, append = TRUE)
        break
      }
    }
    Sys.sleep(runif(1, 0.4, 0.6))
  }
  Sys.sleep(runif(1, 0.9, 1.3))
}

b$close()
cat(sprintf("\ndone: %s\n", out_file))
