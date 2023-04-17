options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

install.packages("remotes")
remotes::install_github("datacamp/testwhat")
remotes::install_github("UCLATALL/coursekata-r", "main")
coursekata::coursekata_install()

install.packages(c(
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "tidyverse"
))
