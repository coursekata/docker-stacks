#!/usr/bin/env bash

# Get Python package names for a given pixi environment
# Uses `pixi list` to get the resolved explicit packages, filtering out
# R packages and system/infrastructure packages.

set -euo pipefail

show_help() {
  cat <<EOF
Get Python package names from pixi.toml for testing

Usage: $0 ENVIRONMENT

Arguments:
  ENVIRONMENT   The pixi environment name (e.g., datascience-notebook)

Output:
  Package names, one per line

Examples:
  $0 datascience-notebook
  $0 essentials-notebook
EOF
}

if [ "$#" -ne 1 ]; then
  show_help
  exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
  exit 0
fi

ENVIRONMENT=$1

pixi_json=$(pixi list -e "$ENVIRONMENT" --json) || exit 1

packages=$(
  echo "$pixi_json" \
    | jq -r '.[] | select(.is_explicit) | select(.name | test("^(r-|python$|pip$|unixodbc$|cmdstan$)") | not) | .name' \
    | sort -u
)

if [ -z "$packages" ]; then
  echo "Error: No packages found for environment '$ENVIRONMENT'" >&2
  exit 1
fi

echo "$packages"
