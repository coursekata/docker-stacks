#!/bin/bash

set -e

packages=(
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
)

for package in "${r_packages[@]}"; do
  Rscript -e "suppressPackageStartupMessages(library($package))"
done

for package in "${py_packages[@]}"; do
  pip show $package &> /dev/null || (echo " ! Python package $package not found" && exit 1)
done
