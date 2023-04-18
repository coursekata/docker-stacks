options(warn = 2, Ncpus = max(1L, parallel::detectCores()))
install.packages("pak")

pak::pkg_install(upgrade = FALSE, pkg = c(
  "datacamp/testwhat",
  "UCLATALL/coursekata-r@main",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "tidyverse"
))
coursekata::coursekata_install()
