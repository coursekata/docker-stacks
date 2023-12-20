options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

# packages also installed in essentials-notebook
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

# packages only in r-notebook and datascience-notebook
remotes::install_cran(upgrade = FALSE, pkgs = c(
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
  "maps",
  "neuralnet",
  "OCSdata",
  "profvis",
  "psych",
  "RcppTOML",
  "reticulate",
  "simstudy",
  "tidymodels",
  "tidyverse"
))
