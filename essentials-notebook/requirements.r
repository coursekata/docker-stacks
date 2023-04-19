options(warn = 2, Ncpus = max(1L, parallel::detectCores()))
install.packages("pak")

pak::pkg_install(upgrade = FALSE, pkg = c(
  "datacamp/testwhat",
  "UCLATALL/coursekata-r@main",
  "fivethirtyeightdata/fivethirtyeightdata",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "tidyverse"
))
