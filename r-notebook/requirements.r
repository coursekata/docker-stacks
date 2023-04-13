options(warn = 2, Ncpus = max(1L, parallel::detectCores()))

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
  "remotes",
  "reticulate",
  "sf",
  "simstudy",
  "statmod",
  "stringi",
  "tidymodels",
  "tidyverse",
  "transformr"
))

remotes::install_github("datacamp/testwhat")

remotes::install_github("UCLATALL/coursekata-r", "main")
coursekata::coursekata_install()
