#!/bin/bash

set -euo pipefail

# check if PIXI_ENV is set
if [ -z "${PIXI_ENV:-}" ]; then
  echo "Error: PIXI_ENV is not set."
  exit 1
fi

# -----------------------------------------------------------------------------
# Environment dependencies
# -----------------------------------------------------------------------------
declare -A modern_notebook_packages
modern_notebook_packages[bin]="pandoc"

declare -A base_r_packages
base_r_packages[bin]="R python bash git"
base_r_packages[r]="IRkernel remotes"

declare -A essentials_packages
essentials_packages[r]="fivethirtyeightdata testwhat Lock5withR coursekata fivethirtyeight gridExtra ggpubr lme4 minqa plotly statmod"

declare -A ckcode_packages
ckcode_packages[python]="pythonwhat"

declare -A r_packages
r_packages[r]="mobilizr V8 gganimate av gifski bayesplot broom.mixed car dagitty DHARMa easystats emmeans ggdag ggeffects gt gtsummary here janitor lmerTest loo mapdata mapproj marginaleffects neuralnet OCSdata posterior profvis psych RcppTOML reticulate simstudy sjPlot Stat2Data tidybayes tidymodels tidyverse"

declare -A r_datascience_packages
r_datascience_packages[bin]="clang++"
r_datascience_packages[r]="cmdstanr rethinking flexplot mlpwr brms dlookr extraDistr ggstatsplot modelsummary pwr pwrss rstanarm tidyplots"

declare -A datascience_packages
datascience_packages[python]="ipywidgets matplotlib nltk numpy openpyxl pandas plotly scikit-learn seaborn statsmodels cmdstanpy altair altair-latimes beautifulsoup4 bokeh contextily dash dash-cytoscape folium gensim geopandas dtreeviz mapclassify networkx researchpy scipy spotipy vega_datasets wordcloud yahoo-fin yellowbrick"

declare -A packages
packages[base-r]=base_r_packages
packages[essentials]=essentials_packages
packages[r]=r_packages
packages[r-datascience]=r_datascience_packages
packages[datascience]=datascience_packages
packages[modern-notebook]=modern_notebook_packages
packages[ckcode]=ckcode_packages

declare -A environments
environments[base-r]="default base-r modern-notebook"
environments[essentials]="default base-r essentials modern-notebook"
environments[r]="default base-r essentials r modern-notebook"
environments[r-datascience]="default base-r essentials r r-datascience modern-notebook"
environments[datascience]="default base-r essentials r r-datascience datascience modern-notebook"

environments[ckcode]="default base-r essentials ckcode modern-notebook"
environments[ckhub]="default base-r essentials r r-datascience datascience ckhub"

environments[deepnote-base-r]="default base-r deepnote"
environments[deepnote-essentials]="default base-r essentials deepnote"
environments[deepnote-r]="default base-r essentials r deepnote"
environments[deepnote-datascience]="default base-r essentials r r-datascience deepnote"

# -----------------------------------------------------------------------------
# CLI utlities
# -----------------------------------------------------------------------------

h1() {
  # Bold and blue
  printf "\033[1;34m%s\033[0m\n" "$1"
}

h2() {
  # Blue
  printf "\033[34m%s\033[0m\n" "$1"
}

success() {
  # Green
  printf "\033[32m%s\033[0m\n" "$1"
}

inform() {
  # Grey
  printf "\033[90m%s\033[0m\n" "$1"
}

warn() {
  # Yellow
  printf "\033[33m%s\033[0m\n" "$1"
}

error() {
  # Red
  printf "\033[31m%s\033[0m\n" "$1"
}

# -----------------------------------------------------------------------------
# Test functions
# -----------------------------------------------------------------------------
get_package_list() {
  local feature=$1
  local type=$2

  # Resolve the name of the associative array for the given feature
  local feature_array_name="${packages[$feature]}"
  if [ -z "$feature_array_name" ]; then
    inform "No package group found for feature: $feature."
  fi

  # Dynamically reference the array using declare -n
  declare -n feature_array="$feature_array_name"

  # Extract the package list for the given type (e.g., bin, r, python)
  echo "${feature_array[$type]:-}"
}

test_binaries() {
  local feature=$1
  local pkg_str=$(get_package_list "$feature" "bin")
  IFS=' ' read -r -a pkgs <<< "$pkg_str"

  if [ ${#pkgs[@]} -eq 0 ]; then
    h2 "[$feature] No binaries to test."
    return 0
  fi

  h2 "[$feature] Testing binaries: ${pkg_str}"
  for pkg in "${pkgs[@]}"; do
    inform "Checking $pkg"
    $pkg --version
  done
}

# test python package by calling pip show
test_python() {
  local feature=$1
  local pkg_str=$(get_package_list "$feature" "python")
  IFS=' ' read -r -a pkgs <<< "$pkg_str"

  if [ ${#pkgs[@]} -eq 0 ]; then
    h2 "[$feature] No Python packages to test."
    return 0
  fi

  h2 "[$feature] Testing Python packages: ${pkg_str}"
  py_output=$(pip show "${pkgs[@]}" 2>&1 || true)
  warning_prefix="WARNING: Package(s) not found"
  py_warning=$(echo "$py_output" | grep "${warning_prefix}" || true)
  if echo "$py_output" | grep -q "${warning_prefix}"; then
    error $py_warning
    return 1
  fi

  return 0
}

# test R packages by calling Rscript -e 'options(warn = 2); library(pkg)'
test_r() {
  local feature=$1
  local pkg_str=$(get_package_list "$feature" "r")
  IFS=' ' read -r -a pkgs <<< "$pkg_str"

  if [ ${#pkgs[@]} -eq 0 ]; then
    h2 "[$feature] No R packages to test."
    return 0
  fi

  h2 "[$feature] Testing R packages: ${pkg_str}"
  # convert R packages into an R array string like "c('package1', 'package2')"
  r_str=$(printf ", '%s'" "${pkgs[@]}")
  r_str="c(${r_str:2})"
  Rscript -e "
    options(warn = 2)

    loader <- function(x) {
      tryCatch({
        suppressPackageStartupMessages(library(x, character.only = TRUE))
      }, error = function(e) {
        cat('Error: Failed to load package ', x, '\n', sep = '')
        stop(e)
      })
    }

    load_all <- function(x) invisible(lapply(x, loader))
    load_all($r_str)
  " || {
      error "Error: One or more R packages failed to load."
      return 1
    }

  return 0
}


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
# get the features for the current environment
h1 "Testing packages for $PIXI_ENV environment. Loaded features: ${environments[$PIXI_ENV]}"

# for each feature, test the packages if the feature is defined
for feature in ${environments[$PIXI_ENV]}; do
  if [ -n "${packages[$feature]:-}" ]; then
    h1 "Testing packages for $feature"
    test_binaries "$feature"
    test_python "$feature"
    test_r "$feature"
  fi
done
