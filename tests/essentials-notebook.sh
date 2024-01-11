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
  pak
  plotly
  statmod
)

py_packages=(
  # base
  # essentials
  pythonwhat
)

"$(dirname "$0")/test-r-packages.sh" "${r_packages[@]}" & r_pid=$!
"$(dirname "$0")/test-python-packages.sh" "${py_packages[@]}" & py_pid=$!
for job in $r_pid $py_pid; do wait $job || exit 1; done
echo -e "\033[32mAll tests passed!\033[0m"
