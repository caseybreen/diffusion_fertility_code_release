## Digital Diffusion: Mobile Internet and the Spread of Cultural Scripts about Family Life

[![OSF](https://img.shields.io/badge/OSF-project-blue)]([https://osf.io/5e8wf/]())
[![Generic badge](https://img.shields.io/badge/R-4.5.1-orange.svg)](https://cran.r-project.org/bin/macosx/)
[![Generic badge](https://img.shields.io/badge/License-GNU-<green>.svg)](https://www.gnu.org/licenses/gpl-3.0.en.html)
[![Generic badge](https://img.shields.io/badge/Maintained-Yes-red.svg)]()

This repository contains code and materials to replicate the paper "Digital Diffusion: Mobile Internet and the Spread of
Cultural Scripts about Family Life."

**Abstract**: 
Global cultural diffusion theories have long emphasized how institutional actors such as 
intergovernmental organizations, international non-governmental organizations, and state 
agencies spread cultural scripts. We theorize that mobile internet constitutes a qualitatively
distinct pathway for the diffusion of these scripts, shifting exposure from institutionally
mediated and episodic to more individualized, continuous, and algorithmically curated. This
reconfiguration changes both which cultural models individuals encounter and the frequency
with which individuals are exposed to them. Using the staggered rollout of mobile internet
across Nigeria as an empirical case, we find that expanding coverage reduces fertility, 
corresponding to a 9\% relative decline in the annual probability of birth, consistent with
shifts in contraceptive use, ideal family size, and women’s autonomy in financial and
healthcare decision-making. These findings suggest that digital infrastructure does not 
simply extend existing diffusion processes but can reshape them, with measurable consequences
for family life. 

### Replication Package

------------


This repository includes code to replicate all figures and tables in the paper. To replicate, follow
the steps outlined below: 

1. Clone this repository
2. Download the `data.zip` file from the [OSF repository - TODO ADD LIKNK], move it to the root level of this repository, and unzip it. 
2. Run the `00_run_all.Rmd` script, which will run all code (or run scripts `01` to `4` individually)

### Data 

------------


Please download the `data.zip` file from the Open Science Framework repository. At the root level of this repository (alongside the `code/` folder), unzip 
the archive to create a `data/` folder containing all required data files for the analysis.

### Code 

------------


After downloading the required data, researchers can run the following script to replicate all figures and tables in the paper:

`00_run_all.Rmd` — This file runs all scripts.

Alternatively, researchers can run the following files individually in order:

`01_generate_analysis_file.Rmd` — Construct the individual-level panel dataset by merging DHS birth and women's recodes with 3G coverage data, cluster-to-admin2 crosswalks, and time-varying covariates.
`02_mobile_coverage_plots.Rmd` — Visualize the expansion of 3G coverage in Nigeria (2010–2018) and plot mobile phone ownership by coverage level.
`03_tfr_unadjusted.Rmd` — Estimate total fertility rates stratified by 3G coverage and mobile phone ownership using DHS rate calculations with jackknife standard errors.
`04_twfe_analysis.Rmd` — Fit two-way fixed effects (TWFE) models estimating the effect of 3G expansion on birth probability, estimate heterogeneous effects by nightlight intensity, phone ownership, union type, and region, and run a Sun and Abraham event study.
`05_mechanisms.Rmd` — Investigate mechanisms including age at first sex, age at first cohabitation, ideal family size, employment, contraceptive use and knowledge, and women's empowerment.
`06_infant_mortality.Rmd` — Estimate the effect of 3G coverage on infant mortality.
`07_google_trends.Rmd` — Query Google Trends for contraception and family size search terms in Nigeria (note: excluded from 00_run_all.Rmd as the API can be unreliable).
`08_ideal_family_size_2013_2018.Rmd` — Analyze shifts in women's ideal number of children between the 2013 and 2018 DHS surveys using IPUMS-DHS data.

### Authors

- [Casey Breen](https://caseybreen.com)
- [Till Koebe](https://scholar.google.com/citations?user=uMxfnUUAAAAJ&hl=de)
- [Ridhi Kashyap](https://www.sociology.ox.ac.uk/people/ridhi-kashyap)



## Replication

All analyses and computations were carried out on 2024 MacBook Pro with an Apple M4 Pro chip, 48GB memory, and Sequoia 15.7 operating system.

All analyses were originally conducted using R version 4.5.1 and the package versions recorded in the attached session info at the bottom of the README. 


## Acknowledgements 

For helpful discussions and feedback, we thank Leigh Senderowicz, Aashish Gupta, Michelle Niemann,
Michelle Poulin, and audiences at the at the Max Planck Institute for Demographic Research (MPIDR)
and Population Association of America session. We thank Xinyi Zhao and Jiaxuan Li for research assistance.
We acknowledge financial support from the Bill and Melinda Gates Foundation (INV-045370), the Leverhulme 
Trust for the Leverhulme Centre for Demographic Science (RC-2018-003) and Leverhulme Prize,
and infrastructure grants from the Eunice Kennedy Shriver National Institute of Child Health and
Human Development (P2CHD042849) and the National Institute on Aging (NIA) (P30AG066614).

## Session info:

```
sessionInfo()

R version 4.5.1 (2025-06-13)
Platform: aarch64-apple-darwin20
Running under: macOS Sequoia 15.7.2

Matrix products: default
BLAS:   /System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/libBLAS.dylib 
LAPACK: /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libRlapack.dylib;  LAPACK version 3.12.1

locale:
 en_US.UTF-8/en_US.UTF-8/en_US.UTF-8/C/en_US.UTF-8/en_US.UTF-8

time zone: America/Chicago
tzcode source: internal

attached base packages:
stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
 [1] scales_1.4.0        gompertztrunc_0.1.2 ipumsr_0.9.0        RColorBrewer_1.1-3  LexisPlotR_0.4.0    gt_1.1.0            fixest_0.12.1      
 [8] broom_1.0.9         cowplot_1.2.0       ggrepel_0.9.6       lubridate_1.9.4     forcats_1.0.0       stringr_1.5.1       dplyr_1.1.4        
[15] purrr_1.1.0         readr_2.1.5         tidyr_1.3.1         tibble_3.3.0        ggplot2_3.5.2       tidyverse_2.0.0     data.table_1.17.8  
[22] here_1.0.1         

loaded via a namespace (and not attached):
 [1] gtable_0.3.6        xfun_0.53           lattice_0.22-7      tzdb_0.5.0          numDeriv_2016.8-1.1 vctrs_0.6.5         tools_4.5.1        
 [8] generics_0.1.4      sandwich_3.1-1      pacman_0.5.1        pkgconfig_2.0.3     stringmagic_1.2.0   lifecycle_1.0.4     compiler_4.5.1     
[15] farver_2.1.2        textshaping_1.0.3   ggsci_3.2.0         codetools_0.2-20    htmltools_0.5.8.1   Formula_1.2-5       pillar_1.11.0      
[22] crayon_1.5.3        nlme_3.1-168        tidyselect_1.2.1    digest_0.6.37       stringi_1.8.7       labeling_0.4.3      rprojroot_2.1.1    
[29] fastmap_1.2.0       grid_4.5.1          cli_3.6.5           magrittr_2.0.3      withr_3.0.2         dreamerr_1.5.0      backports_1.5.0    
[36] timechange_0.3.0    ragg_1.5.0          zoo_1.8-14          hms_1.1.3           evaluate_1.0.5      knitr_1.50          haven_2.5.5        
[43] rlang_1.1.6         Rcpp_1.1.0          zeallot_0.2.0       glue_1.8.0          xml2_1.4.0          rstudioapi_0.17.1   R6_2.6.1           
[50] systemfonts_1.2.3   fs_1.6.6

```
