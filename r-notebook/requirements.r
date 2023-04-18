options(warn = 2, Ncpus = max(1L, parallel::detectCores()))
install.packages("pak")

# packages also installed in essentials-notebook
pak::pkg_install(upgrade = FALSE, pkg = c(
  "datacamp/testwhat",
  "UCLATALL/coursekata-r@main",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "tidyverse"
))
coursekata::coursekata_install()

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
