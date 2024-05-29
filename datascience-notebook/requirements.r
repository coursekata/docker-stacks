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

# packages for r-notebook
remotes::install_github(c(
  "mobilizingcs/mobilizr"
))

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

# packages for datascience-notebook
remotes::install_cran(c(
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
