options(warn = 2, Ncpus = max(1L, parallel::detectCores()))
install.packages("pak")
install.packages("digest", repos = "https://eddelbuettel.r-universe.dev", type = "source")

pak::pkg_install(upgrade = FALSE, pkg = c(
  "coursekata/testwhat",
  "coursekata/coursekata-r",
  "fivethirtyeightdata/fivethirtyeightdata",
  "supernova",
  "dslabs",
  "fivethirtyeight",
  "lsr",
  "mosaic",
  "Lock5withR",
  "ggpubr",
  "gridExtra",
  "lme4",
  "minqa",
  "plotly",
  "statmod",
  "dplyr",
  "readr"
))
