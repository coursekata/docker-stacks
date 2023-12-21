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
)

py_packages=(
  # base
  # essentials
  pythonwhat
)

for package in "${r_packages[@]}"; do
  Rscript -e "suppressPackageStartupMessages(library($package))"
done

for package in "${py_packages[@]}"; do
  pip show $package &> /dev/null || (echo " ! Python package $package not found" && exit 1)
done

echo "All tests passed!"
