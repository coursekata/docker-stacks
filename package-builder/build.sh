#!/bin/bash

# This script downloads an R package source from CRAN or GitHub and builds a binary package for the
# given platform. The binary package can then be installed on the target platform without requiring
# compilation.

# exit on error
set -e

# check that a package name was provided
if [ -z "$1" ]; then
  echo "No package name provided"
  exit 1
else
  package=$1
fi

# Function to handle SIGINT (Ctrl+C) signal
cleanup() {
  echo "Received Ctrl+C. Exiting..."
  exit 0
}

# Trap SIGINT and call the cleanup function
trap 'cleanup' INT

echo ""
echo "Building package ${package}"
echo "=========================="
echo ""
echo "Downloading source files from GitHub"
echo "--------------------------"

pkg_dir="/tmp/$(basename "${package}")"

if [ -z "$2" ]; then
  gh repo clone "${package}" "${pkg_dir}" -- --depth 1
else
  gh repo clone "${package}" "${pkg_dir}" -- --depth 1 --branch "${2}"
fi

echo ""
echo "Building package"
echo "--------------------------"

# build the package
Rscript -e "devtools::install_deps('${pkg_dir}')"
Rscript -e "devtools::build('${pkg_dir}', path = '~', binary = TRUE, args = c('--as-cran'))"
