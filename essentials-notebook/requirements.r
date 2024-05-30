options(Ncpus = max(1L, parallel::detectCores() - 1), warn = 2)

remotes::install_github(c(
  "coursekata/fivethirtyeightdata",
  "coursekata/Lock5withR",
  "coursekata/testwhat"
))

remotes::install_cran(c(
  "coursekata",
  "fivethirtyeight",
  "ggpubr",
  "gridExtra",
  "lme4",
  "plotly",
  "statmod"
))
