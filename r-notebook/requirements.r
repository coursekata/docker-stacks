options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

install.packages("remotes")
remotes::install_github("datacamp/testwhat")
remotes::install_github("UCLATALL/coursekata-r", "main")
coursekata::coursekata_install()

install.packages(c(
  "av",
  "car",
  "ClustOfVar",
  "cluster",
  "dagitty",
  "jtools",
  "gganimate",
  "ggdag",
  "ggformula",
  "ggpubr",
  "gifski",
  "here",
  "lme4",
  "magrittr",
  "mapdata",
  "mapproj",
  "maps",
  "minqa",
  "mosaic",
  "OCSdata",
  "plotly",
  "profvis",
  "psych",
  "RcppTOML",
  "reticulate",
  "sf",
  "simstudy",
  "statmod",
  "stringi",
  "tidymodels",
  "tidyverse",
  "transformr"
))
