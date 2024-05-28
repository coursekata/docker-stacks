options(Ncpus = max(1L, parallel::detectCores()))

remotes::install_github(c(
  "coursekata/testwhat",
  "fivethirtyeightdata/fivethirtyeightdata",
  "rpruim/Lock5withR"
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
