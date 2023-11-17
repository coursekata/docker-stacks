options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

remotes::install_github(upgrade = FALSE, "coursekata/testwhat")
remotes::install_github(upgrade = FALSE, "fivethirtyeightdata/fivethirtyeightdata")
remotes::install_cran(upgrade = FALSE, pkgs = c(
  "coursekata",
  "fivethirtyeight",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod"
))

coursekata::coursekata_install()
