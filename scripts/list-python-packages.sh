#!/usr/bin/env bash

# Get Python package names for a given pixi environment
# Extracts packages from both regular dependencies and pypi-dependencies

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

# Use pixi to get the environment info as JSON
pixi_info=$(pixi info --manifest-path pixi.toml --json 2>/dev/null)

# Get features for this environment
features=$(echo "$pixi_info" | jq -r \
  ".environments_info[] | select(.name == \"$ENVIRONMENT\") | .features[]" \
  2>/dev/null || true)

if [ -z "$features" ]; then
  echo "Error: Environment '$ENVIRONMENT' not found in pixi.toml" >&2
  exit 1
fi

# Collect Python packages from pixi.toml
# We need to parse the TOML file to get pypi-dependencies
# For now, use a simple approach with awk

get_python_deps() {
  local feature=$1
  local toml_file="pixi.toml"

  # Get regular Python dependencies from [feature.X.dependencies]
  # Filter out R packages (start with r-), system packages, and base packages
  awk -v feature="$feature" '
    $0 == "[feature."feature".dependencies]" { in_section=1; next }
    $0 == "[feature."feature".pypi-dependencies]" { in_pypi=1; next }
    /^\[/ { in_section=0; in_pypi=0 }
    in_section && /^[a-zA-Z0-9_-]+ *=/ {
      # Extract package name (everything before =)
      sub(/ *=.*/, "")
      pkg = $0
      # Filter out R packages, Python interpreter, pip
      if (pkg !~ /^(r-|python$|pip$|unixodbc|cmdstan)/) {
        print pkg
      }
    }
    in_pypi && /^[a-zA-Z0-9_-]+ *=/ {
      # Extract package name from pypi-dependencies
      sub(/ *=.*/, "")
      print $0
    }
  ' "$toml_file"
}

# Collect packages from all features
all_packages=()

for feature in $features; do
  while IFS= read -r pkg; do
    [ -n "$pkg" ] && all_packages+=("$pkg")
  done < <(get_python_deps "$feature")
done

# Remove duplicates and sort (only if we have packages)
if [[ ${#all_packages[@]} -gt 0 ]]; then
  printf '%s\n' "${all_packages[@]}" | sort -u
fi
