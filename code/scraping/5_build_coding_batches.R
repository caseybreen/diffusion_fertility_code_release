#!/usr/bin/env Rscript
## Split the ideal-candidate posts into batches for LLM coding, and identify
## childfree (zero-ideal) candidate posts. The coding itself is performed by
## LLM passes under fixed codebooks (see paper appendix); outputs land in
## data/nairaland/raw/coding/ as ideals_coded_*.csv, zero_coded.csv, and
## rationale_coded_*.csv, which Rmds 12-13 consume.
## Usage: Rscript code/scraping/5_build_coding_batches.R  (from the repo root)

## Library packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, here)

set.seed(2026)
cod <- here("data", "nairaland", "raw", "coding")
dir.create(cod, recursive = TRUE, showWarnings = FALSE)

## ideal-size extraction batches
cand <- read_csv(here("data", "nairaland", "prep", "ideal_candidates_full.csv"),
                 show_col_types = FALSE) %>%
  slice_sample(prop = 1)
splits <- cut(seq_len(nrow(cand)), 6, labels = FALSE)
for (i in 1:6) {
  write_csv(cand[splits == i, ], file.path(cod, sprintf("ideal_batch_%d.csv", i - 1)))
}

## childfree (zero-ideal) candidates
posts <- read_csv(here("data", "nairaland", "prep", "posts_complete.csv"),
                  show_col_types = FALSE)
zero_rx <- regex(paste(
  "childfree", "child free", "child-free",
  "no kids for me", "no children for me",
  "don'?t want (any )?(kids|children|a child)",
  "do not want (any )?(kids|children)",
  "never (want|wanted|having) (kids|children)",
  "not hav(e|ing) (any )?(kids|children)",
  "zero (kids|children)", "no (kids|children) at all",
  "remain childless", "stay childless", "without (kids|children) by choice",
  sep = "|"), ignore_case = TRUE)

zero_cand <- posts %>%
  filter(nwords >= 5, nwords <= 300,
         str_detect(replace_na(text, ""), zero_rx)) %>%
  mutate(post_year = coalesce(suppressWarnings(year(mdy(date))), year))
write_csv(zero_cand %>% select(tid, page, k, post_year, title, text),
          file.path(cod, "zero_cand.csv"))

cat("ideal batches: 6 x ~", ceiling(nrow(cand) / 6),
    "| zero candidates:", nrow(zero_cand), "\n")

## stage two (run again after the ideals coding lands): rationale batches
ideals_files <- list.files(cod, pattern = "^ideals_coded_\\d\\.csv$", full.names = TRUE)
if (length(ideals_files) == 6) {
  ideals <- map_dfr(ideals_files, read_csv, show_col_types = FALSE) %>%
    filter(has_ideal == 1, !is.na(ideal_n)) %>%
    inner_join(cand %>% select(tid, page, k, post_year, title, text),
               by = c("tid", "page", "k")) %>%
    slice_sample(prop = 1)
  splits2 <- cut(seq_len(nrow(ideals)), 2, labels = FALSE)
  for (i in 1:2) {
    write_csv(ideals[splits2 == i,
                     c("tid", "page", "k", "ideal_n", "post_year", "title", "text")],
              file.path(cod, sprintf("rationale_batch_%d.csv", i - 1)))
  }
  cat("rationale batches: 2 x ~", ceiling(nrow(ideals) / 2), "\n")
}

## stage three (after all ideal coding lands): assemble one tidy ideals file.
## Sources: the 32 full-sweep batches (every post in the windowed threads read
## individually) plus the earlier regex-candidate batches and the childfree pass.
sweep_out <- list.files(cod, pattern = "^sweep_coded_\\d+\\.csv$", full.names = TRUE)
ideals_out <- list.files(cod, pattern = "^ideals_coded_\\d\\.csv$", full.names = TRUE)
if (length(sweep_out) > 0 || length(ideals_out) > 0) {
  ## censused domains only: fertility-core and parenting-cost threads were
  ## collected exhaustively; the views-sampled polygyny/autonomy threads are
  ## excluded so the ideals corpus is a complete census of its domains
  census_tids <- read_csv(here("data", "nairaland", "prep", "threads_analysis.csv"),
                          show_col_types = FALSE) %>%
    filter(fertility_core | d_parenting_cost == 1) %>%
    pull(thread_id)

  posts_all <- read_csv(here("data", "nairaland", "prep", "posts_complete.csv"),
                        show_col_types = FALSE) %>%
    filter(tid %in% census_tids) %>%
    mutate(post_year = coalesce(suppressWarnings(year(mdy(date))), year)) %>%
    select(tid, page, k, post_year)

  coded_ideals <- bind_rows(
    map_dfr(sweep_out, read_csv, show_col_types = FALSE),
    map_dfr(ideals_out, read_csv, show_col_types = FALSE)) %>%
    filter(has_ideal == 1, !is.na(ideal_n), ideal_n >= 0, ideal_n <= 20) %>%
    distinct(tid, page, k, .keep_all = TRUE) %>%
    select(tid, page, k, ideal_n, ideal_kind)

  ## childfree pass (kept for posts the sweep did not already flag)
  if (file.exists(file.path(cod, "zero_coded.csv"))) {
    zero_ideals <- read_csv(file.path(cod, "zero_coded.csv"), show_col_types = FALSE) %>%
      filter(has_zero == 1) %>%
      transmute(tid, page, k, ideal_n = 0, ideal_kind = "own") %>%
      anti_join(coded_ideals, by = c("tid", "page", "k"))
    coded_ideals <- bind_rows(coded_ideals, zero_ideals)
  }

  stated_ideals <- coded_ideals %>%
    inner_join(posts_all, by = c("tid", "page", "k")) %>%
    filter(post_year %in% 2010:2018)

  write_csv(stated_ideals, here("data", "nairaland", "coded_output", "stated_ideals.csv"))
  cat("stated_ideals.csv:", nrow(stated_ideals), "ideals (",
      sum(stated_ideals$ideal_n == 0), "zeros ), mean",
      round(mean(stated_ideals$ideal_n), 2), "\n")
}

## stage four (after rationale coding lands): assemble one tidy rationales file
rat_out <- c(list.files(cod, pattern = "^rationale_coded_\\d\\.csv$", full.names = TRUE),
             list.files(cod, pattern = "^rat_new_coded_\\d+\\.csv$", full.names = TRUE))
if (length(rat_out) >= 2 && file.exists(here("data", "nairaland", "coded_output", "stated_ideals.csv"))) {
  rationales <- map_dfr(rat_out, read_csv, show_col_types = FALSE) %>%
    inner_join(read_csv(here("data", "nairaland", "coded_output", "stated_ideals.csv"),
                        show_col_types = FALSE) %>%
                 distinct(tid, page, k, ideal_n, post_year),
               by = c("tid", "page", "k"))
  write_csv(rationales, here("data", "nairaland", "coded_output", "rationales_coded.csv"))
  cat("rationales_coded.csv:", nrow(rationales), "posts\n")

  ## full version for reading/validation: ideals with thread title, post text,
  ## and rationale codes in one place
  stated_full <- read_csv(here("data", "nairaland", "coded_output", "stated_ideals.csv"),
                          show_col_types = FALSE) %>%
    left_join(read_csv(here("data", "nairaland", "prep", "posts_complete.csv"),
                       show_col_types = FALSE) %>%
                select(tid, page, k, title, text),
              by = c("tid", "page", "k")) %>%
    left_join(rationales %>% select(tid, page, k, rationales),
              by = c("tid", "page", "k")) %>%
    arrange(post_year, tid, page, k)
  write_csv(stated_full, here("data", "nairaland", "coded_output", "stated_ideals_full.csv"))
  cat("stated_ideals_full.csv:", nrow(stated_full), "posts\n")
}
