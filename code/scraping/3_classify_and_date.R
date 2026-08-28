#!/usr/bin/env Rscript
## Classify every census thread title into family-life domains and date every
## thread from Nairaland's sequential thread IDs (calibrated on the observed
## first-post timestamps from 2_scrape_calibration.R; leave-one-out median
## error 2.2 days). Produces the sampling frame that 4_scrape_threads.R
## selects from. No network access — pure processing.
##
## Usage:   Rscript code/scraping/3_classify_and_date.R   (from the repo root)
## Inputs:  data/nairaland/family_listings.jsonl, data/nairaland/calibration.jsonl
## Output: data/nairaland/threads_dated.csv

## Library packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, jsonlite, here)

## ---- 1. classify thread titles into domains -----------------------------------
## title keyword rules; fertility-core = family_size + childbearing + family_planning
domains <- list(
  family_size = c(
    "family size", "number of (child|children|kids)",
    "how many (kids|children|babies)", "many children", "many kids",
    "small family", "large famil", "big famil(y|ies)",
    "ideal famil", "four children", "5 children", "five children",
    "six children", "6 children", "seven children", "7 children"),
  childbearing = c(
    "child ?bearing", "childbirth", "give birth", "giving birth",
    "have (a )?bab(y|ies)", "having (a )?bab(y|ies)",
    "have (more )?children", "having (more )?children",
    "childless", "child[- ]?free", "no kids", "without children",
    "waiting on the lord", "trying to conceive", "ttc\\b"),
  family_planning = c(
    "family planning", "birth control", "contracept",
    "child spacing", "condom", "iud\\b", "postinor",
    "prevent(ing)? pregnancy", "unwanted pregnanc",
    "abortion", "vasectomy"),
  union_formation = c(
    "\\bmarry\\b", "marriage", "married", "wedding", "husband material",
    "single (mother|mum|mom|lad(y|ies))", "spinster",
    "bride ?price", "court(ship)?\\b", "co ?habit"),
  polygyny = c(
    "polygam", "polygyn", "second wife", "2nd wife", "two wives",
    "many wives", "monogam", "co-?wife", "co-?wives"),
  womens_work_autonomy = c(
    "working (wife|wives|mother|mum|mom|woman|women)",
    "house ?wife", "full ?time (house)?wife", "stay[- ]at[- ]home",
    "career wom[ae]n", "bread ?winner", "wife.{0,20}work",
    "woman.{0,15}(earn|salary)", "submission", "submissive wife",
    "feminis", "gender role", "women empowerment"),
  parenting_cost = c(
    "school fees", "cost of (raising|training)",
    "train(ing)? (a |your |my )?child",
    "expensive to raise", "afford (more )?(kids|children)",
    "can'?t afford", "economy.{0,25}(kids|children|famil)",
    "(kids|children).{0,25}economy"))

domain_rx <- map(domains, ~ regex(paste(.x, collapse = "|"), ignore_case = TRUE))

## census scrape: one JSON line per thread
listings <- stream_in(file(here("data", "nairaland", "raw", "family_listings.jsonl")),
                      verbose = FALSE) %>%
  as_tibble() %>%
  distinct(i, .keep_all = TRUE)

threads <- listings %>%
  transmute(thread_id = i, title = t, author = a,
            n_posts = p, n_views = v, board_page = pg)

for (nm in names(domain_rx)) {
  threads[[paste0("d_", nm)]] <-
    as.integer(str_detect(replace_na(threads$title, ""), domain_rx[[nm]]))
}

dcols <- paste0("d_", names(domains))
threads <- threads %>%
  rowwise() %>%
  mutate(domains = paste(names(domains)[c_across(all_of(dcols)) == 1],
                         collapse = ";")) %>%
  ungroup() %>%
  arrange(thread_id) %>%
  relocate(domains, .after = board_page)

cat("threads classified:", nrow(threads), "\n")

## ---- 2. date threads from sequential thread ids --------------------------------
## parse Nairaland dates ("May 28, 2019", or "Jul 14" = current year)
parse_nl_date <- function(s, current_year = 2026) {
  m <- str_match(s, "([A-Z][a-z]{2}) (\\d{1,2})(?:, (\\d{4}))?")
  yr <- if_else(is.na(m[, 4]), as.character(current_year), m[, 4])
  suppressWarnings(mdy(paste0(m[, 2], " ", m[, 3], ", ", yr)))
}

cal <- stream_in(file(here("data", "nairaland", "raw", "calibration.jsonl")),
                 verbose = FALSE) %>%
  as_tibble() %>%
  mutate(date = parse_nl_date(d)) %>%
  filter(!is.na(date), !is.na(i)) %>%
  arrange(i) %>%
  filter(as.numeric(date) == cummax(as.numeric(date)))  ## enforce monotonicity

threads <- threads %>%
  mutate(est_date = as_date(approx(cal$i, as.numeric(cal$date),
                                   xout = thread_id, rule = 2)$y),
         year = year(est_date),
         fertility_core = (d_family_size + d_family_planning + d_childbearing) > 0)

write_csv(threads, here("data", "nairaland", "prep", "threads_dated.csv"))
cat("threads dated:", nrow(threads),
    " fertility-core:", sum(threads$fertility_core), "\n")
