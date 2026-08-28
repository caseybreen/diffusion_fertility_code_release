# Nairaland scraping (all R)

Self-contained scripts that collect and stage everything the Nairaland
analysis uses. Run in order, from the repository root. The shipped dataset in
`data/nairaland/` was collected with these scripts on **August 18, 2026**
(the canonical collection).

| Script | Does | Output (data/nairaland/) | Runtime |
|---|---|---|---|
| `1_scrape_census.R` | Every Family-board thread listing: id, title, creator, post/view counts | `raw/family_listings.jsonl` | ~35 min |
| `2_scrape_calibration.R` | OPTIONAL — first-post timestamps of ~75 threads across the ID range, for ID-interpolated thread dates (kept as a comparison; thread years come primarily from observed first posts) | `raw/calibration.jsonl` | ~3 min |
| `3_classify_and_date.R` | Classify every census title into family-life domains; add ID-interpolated dates when calibration exists (no network) | `prep/threads_dated.csv` | ~2 min |
| `4_scrape_threads.R` | Full text of EVERY page of the topic-selected threads (~1,285 threads) | `raw/threads_fulltext.jsonl` | ~1 h |
| `5_build_coding_batches.R` | Stage posts for the ideal-family-size LLM coding and assemble its outputs: emits candidate/childfree batches, then (rerun after coding lands) rationale batches, then the tidy files | `raw/coding/*_batch_*.csv`, `coded_output/stated_ideals.csv`, `coded_output/stated_ideals_full.csv`, `coded_output/rationales_coded.csv` | seconds |
| `6_build_scripts_batches.R` | Stage the fertility-scripts LLM coding (every post in the family-planning/childbearing threads, 2010-2018) and assemble its outputs, including the opposition (counter-script) pass | `raw/coding/scripts_*.csv`, `coded_output/scripts_coded.csv`, `coded_output/scripts_coded_full.csv` | seconds |

The LLM coding itself runs outside R under fixed codebooks documented in the
paper appendix. Four passes, all archived in `raw/coding/`:

1. **Stated ideals** — every post in the 667 windowed (2010-2018) threads,
   read individually for the poster's own ideal family size
   (`sweep_coded_01..32.csv`; earlier regex-candidate batches
   `ideals_coded_0..5.csv` and the childfree pass `zero_coded.csv` are
   retained and merged). Assembled by script 5 into `coded_output/stated_ideals.csv`;
   feeds Rmd 12.
2. **Rationales** — the reasoning each ideal post gives, under a fixed
   10-category codebook (`rationale_coded_*.csv`, `rat_new_coded_*.csv`).
   Assembled by script 5 into `coded_output/rationales_coded.csv`; feeds Rmds 13-14.
   `recode_econ_coded.csv` / `recode_auto_coded.csv` are refinement passes
   splitting economic cost (subsistence vs investment) and autonomy
   (embodied cost vs decision authority).
3. **Fertility scripts** — every post in the 474 family-planning and
   childbearing threads coded on three binary endorsement dimensions
   (planned fertility; modern contraception/medical authority; female
   reproductive autonomy) (`scripts_coded_01..14.csv`).
4. **Counter-scripts** — the same corpus coded for the mirror opposition
   dimensions (`counter_coded_01..14.csv`). Passes 3-4 are assembled by
   script 6 into `coded_output/scripts_coded.csv`; feed Rmd 15 (the endorsing/opposing
   table).

Human re-validation of coded subsamples (including opposition positives,
which are rare and drive the reported ratios) is required before publication.

## Session mechanics

Nairaland is served behind Cloudflare, so plain HTTP clients are blocked.
Each scraper uses {chromote} to hold a real Chrome session (the challenge
clears automatically — no CAPTCHA) and issues lightweight `fetch()` calls
through it; parsing is rvest, pacing ~1 request/second with jitter and 429
backoff; census and thread scrapes checkpoint per page/thread so interrupted
runs resume. All scripts create their output directories.

If the Cloudflare check does not clear in headless Chrome (common), start a
visible Chrome and attach to it:

```
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 --user-data-dir=/tmp/chromote-profile \
  https://www.nairaland.com/family
```

then rerun with `CHROMOTE_PORT=9222`. Keep that window open for the whole run.

## Collection-date discipline

The census APPENDS (that is how checkpointed resume works), so a fresh run
refuses to start if `family_listings.jsonl` already exists — move the old
frame aside first (e.g. `family_listings_2026-08-18.jsonl`). Rerunning any
scraper collects *today's* Nairaland: counts and page numbers drift as the
forum grows and posts are deleted. Never mix files from different collection
dates in one dataset.

## Data layout (data/nairaland/)

- `raw/` — as-collected material: `family_listings.jsonl` (census),
  `calibration.jsonl`, `threads_fulltext.jsonl`, scrape checkpoint ledgers,
  `coding/` (all LLM batch inputs/outputs), `quotes/` (curated quote candidates).
- `prep/` — deterministic transforms: `threads_dated.csv`,
  `threads_analysis.csv`, `posts_complete.csv`, `ideal_candidates_full.csv`.
- `coded_output/` — assembled analysis files: `stated_ideals(.full).csv`,
  `rationales_coded.csv`, `scripts_coded(_full).csv`.
