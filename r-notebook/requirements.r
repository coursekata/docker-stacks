options(warn = 2)

install_if_missing <- function(pkgs, ...) {
  require_silent <- function(pkg) {
    suppressPackageStartupMessages(require(pkg, character.only = TRUE, quietly = TRUE))
  }

  is_installed <- vapply(pkgs, require_silent, logical(1))
  remotes::install_cran(pkgs[!is_installed], ...)
}

remotes::install_github(c(
  # essentials-notebook
  "coursekata/fivethirtyeightdata",
  "coursekata/Lock5withR",
  "coursekata/testwhat",

  # r-notebook
  "mobilizingcs/mobilizr"
))

install_if_missing(c(
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
  "sjPlot",
  "tidybayes",
  "tidymodels",
  "tidyverse"
))
