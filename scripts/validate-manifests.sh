#!/bin/bash

set -e

# Validate manifest files before building images
# This is a quick pre-flight check to catch syntax errors early

echo "Validating manifest files..."
echo

# Validate pixi.toml
echo "Checking pixi.toml..."
if pixi info --manifest-path pixi.toml >/dev/null 2>&1; then
  echo "✓ pixi.toml is valid"
else
  echo "✗ pixi.toml has errors"
  pixi info --manifest-path pixi.toml
  exit 1
fi

echo

# Validate rpixi.toml
echo "Checking rpixi.toml..."
if Rscript scripts/rpixi.R validate --manifest-path rpixi.toml >/dev/null 2>&1; then
  echo "✓ rpixi.toml is valid"
else
  echo "✗ rpixi.toml has errors"
  Rscript scripts/rpixi.R validate --manifest-path rpixi.toml
  exit 1
fi

echo
echo "All manifest files are valid!"
