#!/bin/bash

set -e

r_packages=(
  # base-r
  IRkernel
  remotes

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

  # r
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
  mobilizr
  neuralnet
  OCSdata
  posterior
  profvis
  psych
  RcppTOML
  reticulate
  simstudy
  tidymodels
  tidyverse
  gt
  gtsummary
  lmerTest
  broom.mixed
  DHARMa
  marginaleffects
  modelsummary
  easystats
  janitor
  loo
  tidybayes
  datapasta
)

py_packages=(
  # base-r

  # essentials
  pythonwhat

  # r
)

"$(dirname "$0")/test-r-packages.sh" "${r_packages[@]}" & r_pid=$!
"$(dirname "$0")/test-python-packages.sh" "${py_packages[@]}" & py_pid=$!
for job in $r_pid $py_pid; do wait $job || exit 1; done
echo -e "\033[32mAll tests passed!\033[0m"
