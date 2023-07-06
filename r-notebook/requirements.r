options(warn = 2, Ncpus = max(1L, parallel::detectCores()))
install.packages("pak")
install.packages("digest", repos = "https://eddelbuettel.r-universe.dev", type = "source")

# packages also installed in essentials-notebook
pak::pkg_install(upgrade = FALSE, pkg = c(
  "datacamp/testwhat",
  "UCLATALL/coursekata-r@main",
  "fivethirtyeightdata/fivethirtyeightdata",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "tidyverse"
))

# packages only in r-notebook and datascience-notebook
pak::pkg_install(upgrade = FALSE, pkg = c(
  "av",
  "car",
  "ClustOfVar",
  "cluster",
  "dagitty",
  "jtools",
  "gganimate",
  "ggdag",
  "gifski",
  "gridExtra",
  "here",
  "mapdata",
  "mapproj",
  "maps",
  "OCSdata",
  "profvis",
  "psych",
  "RcppTOML",
  "reticulate",
  "simstudy",
  "tidymodels",
  "transformr"
))
