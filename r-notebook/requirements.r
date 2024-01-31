options(Ncpus = max(1L, parallel::detectCores()))

# packages already installed in essentials-notebook
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

# packages only in r-notebook and datascience-notebook
remotes::install_cran(c(
  "av",
  "bayesplot",
  "car",
  "dagitty",
  "emmeans",
  "gganimate",
  "ggdag",
  "gifski",
  "here",
  "mapdata",
  "mapproj",
  "neuralnet",
  "OCSdata",
  "posterior",
  "profvis",
  "psych",
  "RcppTOML",
  "reticulate",
  "simstudy",
  "tidymodels",
  "tidyverse"
))
