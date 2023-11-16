options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

remotes::install_github("coursekata/testwhat")
remotes::install_github("fivethirtyeightdata/fivethirtyeightdata")
remotes::install_cran(c(
  "coursekata",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "remotes",
  "statmod"
))
