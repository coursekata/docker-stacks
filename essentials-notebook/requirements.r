options(Ncpus = max(1L, parallel::detectCores()))

remotes::install_github(c(
  "coursekata/coursekata-r",
  "coursekata/testwhat",
  "fivethirtyeightdata/fivethirtyeightdata"
))

remotes::install_cran(c(
  "fivethirtyeight",
  "ggpubr",
  "gridExtra",
  "lme4",
  "plotly",
  "statmod"
))
