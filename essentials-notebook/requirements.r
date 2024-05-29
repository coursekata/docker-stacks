options(Ncpus = max(1L, parallel::detectCores()), warn = 2)

# packages for essentials-notebook
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
