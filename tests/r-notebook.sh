#!/bin/bash

set -e

r_packages=(
  # base
  remotes
  IRkernel
  # essentials
  coursekata
  gridExtra
  fivethirtyeight
  fivethirtyeightdata
  testwhat
  ggpubr
  lme4
  minqa
  plotly
  statmod
  # r-notebook
  av
  bayesplot
  car
  dagitty
  emmeans
  gganimate
  ggdag
  gifski
  here
  mapdata
  mapproj
  maps
  neuralnet
  OCSdata
  profvis
  psych
  RcppTOML
  reticulate
  simstudy
  tidymodels
  tidyverse
)

py_packages=(
  # base
  # essentials
  pythonwhat
  # r-notebook
)

for package in "${r_packages[@]}"; do
  Rscript -e "suppressPackageStartupMessages(library($package))"
done

for package in "${py_packages[@]}"; do
  pip show $package &> /dev/null || (echo " ! Python package $package not found" && exit 1)
done

echo "All tests passed!"
