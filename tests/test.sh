#!/bin/bash

set -euo pipefail

# Write a header in yellow text.
header() {
  echo -e "\n\033[33m$1\033[0m"
}

function get_test_params() {
  local env="$1"
  case "$env" in
    "base-r")
      echo "r/base-r"
      ;;
    "essentials")
      echo "r/base-r r/essentials "
      ;;
    "ckcode")
      echo "r/base-r r/essentials python/ckcode"
      ;;
    "r")
      echo "r/base-r r/essentials r/r"
      ;;
    "datascience")
      echo "r/base-r r/essentials r/r r/datascience python/datascience"
      ;;
    "ckhub")
      echo "r/base-r r/essentials r/r r/datascience python/datascience"
      ;;
    *)
      echo "Error: Test parameters for environment '$env' not found." >&2
      exit 1
      ;;
  esac
}

# check if PIXI_ENV is set
if [ -z "${PIXI_ENV:-}" ]; then
  echo "Error: PIXI_ENV is not set."
  exit 1
fi

# remove "deepnote-" prefix if it exists
env_name="${PIXI_ENV#deepnote-}"

# if the env is base or foundation, there are no tests to run
if [ "$env_name" == "base" ] || [ "$env_name" == "foundation" ]; then
  echo "No tests to run for environment '$env_name'."
  exit 0
fi

# Run the test-packages.sh script with the test parameters
header "Running tests for environment '$env_name'"
$(dirname "$0")/test-packages.sh "$(dirname "$0")/packages.txt" $(get_test_params "$env_name")
