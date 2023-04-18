options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

# packages also installed in essentials-notebook
install.packages("remotes")
remotes::install_github("datacamp/testwhat")
remotes::install_github("UCLATALL/coursekata-r", "main")
coursekata::coursekata_install()
install.packages(c(
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "tidyverse"
))

# packages only in r-notebook and datascience-notebook
install.packages(c(
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
