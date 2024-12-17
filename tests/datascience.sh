#!/bin/bash

set -e

# test cmdstanr installation, which is a little different than other R packages
# set the cmdstan path because it won't be loaded when running this script with bash -c
export CMDSTAN="${CONDA_DIR}/bin/cmdstan"
Rscript -e "options(warn=2); cmdstanr::cmdstan_path() |> invisible()"

$(dirname "$0")/test-packages.sh "$(dirname "$0")/packages.txt" \
  "r/base-r" \
  "r/essentials" \
  "python/essentials" \
  "r/r" \
  "r/datascience" \
  "python/datascience"
