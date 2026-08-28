#!/usr/bin/env Rscript
## Fertility-scripts coding: every post in the windowed (2010-2018)
## family-planning and childbearing threads is coded for three binary
## script dimensions (see paper appendix codebook):
##   planning  - frames fertility as planned (spacing, limiting, stopping, timing)
##   medical   - invokes modern contraceptive methods or expert/medical authority
##   autonomy  - invokes female autonomy/intentionality in reproductive decisions
## Stage one writes coding batches; the coding itself is performed by LLM
## passes; stage two assembles the outputs into data/nairaland/scripts_coded.csv
## and a prevalence summary.
## Usage: Rscript code/scraping/6_build_scripts_batches.R  (from the repo root)

## Library packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, here)

set.seed(2026)
cod <- here("data", "nairaland", "raw", "coding")

## stage one: batches of ~880 posts from family-planning/childbearing threads
th <- read_csv(here("data", "nairaland", "prep", "threads_analysis.csv"),
               show_col_types = FALSE)
posts <- read_csv(here("data", "nairaland", "prep", "posts_complete.csv"),
                  show_col_types = FALSE)

sel <- th %>% filter(d_family_planning == 1 | d_childbearing == 1)
corpus <- posts %>%
  filter(tid %in% sel$thread_id, year %in% 2010:2018, nwords >= 3) %>%
  mutate(post_year = coalesce(suppressWarnings(year(mdy(date))), year)) %>%
  select(tid, page, k, post_year, title, text) %>%
  slice_sample(prop = 1)

if (!file.exists(file.path(cod, "scripts_01.csv"))) {
  nb <- ceiling(nrow(corpus) / 880)
  splits <- cut(seq_len(nrow(corpus)), nb, labels = FALSE)
  for (i in seq_len(nb)) {
    write_csv(corpus[splits == i, ], file.path(cod, sprintf("scripts_%02d.csv", i)))
  }
  cat("scripts batches:", nb, "x ~", ceiling(nrow(corpus) / nb), "posts\n")
}

## stage two (after coding lands): assemble tidy file + prevalence summary
out <- list.files(cod, pattern = "^scripts_coded_\\d+\\.csv$", full.names = TRUE)
if (length(out) > 0) {
  coded <- map_dfr(out, read_csv, show_col_types = FALSE) %>%
    distinct(tid, page, k, .keep_all = TRUE) %>%
    ## batch files use bare names; rename so stance is explicit in the output
    rename(endorses_planning = planning, endorses_modern = medical,
           endorses_autonomy = autonomy) %>%
    inner_join(corpus %>% select(tid, page, k, post_year), by = c("tid", "page", "k")) %>%
    ## same window as the ideals analysis: post-level year (threads dated
    ## 2010-2018 can carry later replies)
    filter(post_year %in% 2010:2018)

  ## counter-script pass (opposition codes over the same corpus), when complete
  counter_out <- list.files(cod, pattern = "^counter_coded_\\d+\\.csv$", full.names = TRUE)
  if (length(counter_out) == length(out)) {
    counter <- map_dfr(counter_out, read_csv, show_col_types = FALSE) %>%
      distinct(tid, page, k, .keep_all = TRUE)
    coded <- coded %>% left_join(counter, by = c("tid", "page", "k"))
    cat(sprintf("  counter-scripts joined: opposes_planning %d | opposes_modern %d | denies_autonomy %d\n",
                sum(coded$opposes_planning), sum(coded$opposes_modern),
                sum(coded$denies_autonomy)))
  }
  write_csv(coded, here("data", "nairaland", "coded_output", "scripts_coded.csv"))

  n <- nrow(coded)
  any_dim <- with(coded, endorses_planning == 1 | endorses_modern == 1 | endorses_autonomy == 1)
  cat(sprintf("scripts_coded.csv: %d posts (%d batches)\n", n, length(out)))
  cat(sprintf("  endorses_planning: %d (%.1f%%)\n", sum(coded$endorses_planning), 100 * mean(coded$endorses_planning)))
  cat(sprintf("  endorses_modern:   %d (%.1f%%)\n", sum(coded$endorses_modern), 100 * mean(coded$endorses_modern)))
  cat(sprintf("  endorses_autonomy: %d (%.1f%%)\n", sum(coded$endorses_autonomy), 100 * mean(coded$endorses_autonomy)))
  cat(sprintf("  any script: %d (%.1f%%)\n", sum(any_dim), 100 * mean(any_dim)))

  ## full version with text, for validation and quote selection: every post
  ## carrying any endorsing OR opposing code
  coded %>%
    filter(endorses_planning == 1 | endorses_modern == 1 | endorses_autonomy == 1 |
             (if ("opposes_planning" %in% names(.))
                opposes_planning == 1 | opposes_modern == 1 | denies_autonomy == 1
              else FALSE)) %>%
    left_join(posts %>% select(tid, page, k, title, text), by = c("tid", "page", "k")) %>%
    write_csv(here("data", "nairaland", "coded_output", "scripts_coded_full.csv"))
}
