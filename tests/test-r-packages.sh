#!/bin/bash

set -e

# convert R packages in to R array string like "c('package1', 'package2')"
r_packages=$(printf ", '%s'" "$@")
r_packages="c(${r_packages:2})"

# test that all R packages load
Rscript -e "\
  loader <- function(x) suppressPackageStartupMessages(library(x, character.only = TRUE)); \
  load_all <- function(x) invisible(lapply(x, loader)); \
  load_all($r_packages) \
"
