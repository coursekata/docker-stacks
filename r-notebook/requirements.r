options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

# packages also installed in essentials-notebook
remotes::install_github(upgrade = FALSE, "coursekata/testwhat")
remotes::install_github(upgrade = FALSE, "fivethirtyeightdata/fivethirtyeightdata")
remotes::install_cran(upgrade = FALSE, pkgs = c(
  "coursekata",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "remotes",
  "statmod"
))


# packages only in r-notebook and datascience-notebook
remotes::install_cran(upgrade = FALSE, pkgs = c(
  "av",
  "car",
  "dagitty",
  "gganimate",
  "ggdag",
  "gifski",
  "gridExtra",
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

stan_repo <- "https://mc-stan.org/r-packages/"
install.packages("cmdstanr", upgrade = FALSE, repos = c(Stan = stan_repo, getOption("repos")))
cmdstanr::install_cmdstan()
