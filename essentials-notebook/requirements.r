options(warn = 2)

install_if_missing <- function(pkgs, ...) {
  require_silent <- function(pkg) {
    suppressPackageStartupMessages(require(pkg, character.only = TRUE, quietly = TRUE))
  }

  is_installed <- vapply(pkgs, require_silent, logical(1))
  remotes::install_cran(pkgs[!is_installed], ...)
}

remotes::install_github(c(
  "coursekata/fivethirtyeightdata",
  "coursekata/Lock5withR",
  "coursekata/testwhat"
))

install_if_missing(c(
  "coursekata",
  "fivethirtyeight",
  "ggpubr",
  "gridExtra",
  "lme4",
  "plotly",
  "statmod"
))
