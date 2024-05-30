options(Ncpus = max(1L, parallel::detectCores() - 1), warn = 2)

remotes::install_github(c(
  # essentials-notebook
  "coursekata/fivethirtyeightdata",
  "coursekata/Lock5withR",
  "coursekata/testwhat",

  # r-notebook
  "mobilizingcs/mobilizr"
))

remotes::install_cran(c(
  # essentials-notebook
  "coursekata",
  "fivethirtyeight",
  "ggpubr",
  "gridExtra",
  "lme4",
  "plotly",
  "statmod",

  # r-notebook
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
  "tidyverse",

  # datascience-notebook
  "brms",
  "ggstatsplot",
  "rstanarm"
))

remotes::install_cran(repos = "https://mc-stan.org/r-packages/", c(
  "cmdstanr"
))

remotes::install_github(c(
  "rmcelreath/rethinking"
))
