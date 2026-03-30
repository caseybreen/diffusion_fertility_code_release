# Install and load pacman if not already installed
if (!require("pacman")) install.packages("pacman")

options(modelsummary_format_numeric_latex = "plain") # no \num in LaTeX

# Use pacman to load all necessary packages
pacman::p_load(
  tidyverse,      # Data manipulation and visualization
  here,           # File paths
  fixest,         # Fixed effects models
  janitor,        # Clean column names
  haven,          # Import data from Stata/SPSS/SAS
  modelsummary,   # Regression tables
  splines,        # Spline basis functions
  ggrepel,        # Library ggrepel     
  cowplot,        # Construct beautiful plots 
  DHS.rates,      # Calculate DHS rates
  ggsci,          # Colors for ggplot 
  survey,          # Survey package 
  gtrendsR,
  zoo)

## custom color schemes
cudb <- c("#49b7fc", "#ff7b00", "#17d898", "#ff0083", "#0015ff", "#e5d200", "#999999")
cud <- c("#D55E00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2", "#E69F00", "#F0E442", "#999999")


## Source .Rmd 
source_rmd = function(file, ...) {
  tmp_file = tempfile(fileext=".R")
  on.exit(unlink(tmp_file), add = TRUE)
  knitr::purl(file, output=tmp_file, quiet = T)
  source(file = tmp_file, ...)
}


# Confidence intervals
interval1 <- -qnorm((1 - 0.90) / 2)
interval2 <- -qnorm((1 - 0.95) / 2)

# Demography theme 
theme_demography <- function() {
  theme(
    axis.title.x = element_text(face = "bold", colour = "black"),
    axis.title.y = element_text(face = "bold", colour = "black")
  )
}