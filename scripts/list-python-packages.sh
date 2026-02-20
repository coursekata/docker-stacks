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

# Non-Python packages to exclude from testing.
# R packages are excluded separately via the "^r-" prefix pattern in jq.
EXCLUDE_PACKAGES=(
  # Infrastructure
  python
  pip
  # System / build tools
  cmdstan
  ocl-icd-system
  pkg-config
  unixodbc
  xorg-xorgproto
)

# Build jq-compatible regex: ^(r-|python$|pip$|...)
exclude_exact=$(printf "|%s$" "${EXCLUDE_PACKAGES[@]}")
exclude_regex="^(r-${exclude_exact})"

pixi_json=$(pixi list -e "$ENVIRONMENT" --json) || exit 1

packages=$(
  echo "$pixi_json" \
    | jq -r --arg regex "$exclude_regex" '.[] | select(.requested_spec != null) | select(.name | test($regex) | not) | .name' \
    | sed 's/^jupyterhub-singleuser$/jupyterhub/' \
    | sort -u
)

if [ -z "$packages" ]; then
  echo "Error: No packages found for environment '$ENVIRONMENT'" >&2
  exit 1
fi

echo "$packages"
