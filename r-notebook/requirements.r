options(Ncpus = max(1L, parallel::detectCores()))

# packages already installed in essentials-notebook
remotes::install_github(c(
  "coursekata/coursekata-r",
  "coursekata/testwhat",
  "fivethirtyeightdata/fivethirtyeightdata",
  "mobilizingcs/mobilizr"
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
  "broom.mixed",
  "car",
  "dagitty",
  "datapasta",
  "DHARMa",
  "easystats",
  "emmeans",
  "gganimate",
  "ggdag",
  "ggeffects",
  "gifski",
  "gt",
  "gtsummary",
  "here",
  "janitor",
  "lmerTest",
  "loo",
  "mapdata",
  "mapproj",
  "marginaleffects",
  "neuralnet",
  "OCSdata",
  "posterior",
  "profvis",
  "psych",
  "RcppTOML",
  "reticulate",
  "simstudy",
  "tidybayes",
  "tidymodels",
  "tidyverse"
))
