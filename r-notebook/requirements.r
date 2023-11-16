options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

# packages also installed in essentials-notebook
remotes::install_github("coursekata/testwhat")
remotes::install_github("fivethirtyeightdata/fivethirtyeightdata")
remotes::install_cran(c(
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
remotes::install_cran(c(
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

install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
cmdstanr::install_cmdstan()
