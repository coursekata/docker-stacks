#!/bin/bash

set -euo pipefail

if ! jupyter server --version &> /dev/null; then
  echo "Warning: jupyter server is not installed."
else
  jupyter server --generate-config
fi

if ! jupyter lab --version &> /dev/null; then
  echo "Warning: jupyter lab is not installed."
else
  # Check for packages that would require a Jupyter Lab rebuild
  if pip show dash &> /dev/null; then
    jupyter lab build --minimize=False
  fi
  jupyter lab clean
fi

rm -rf "${HOME}/.cache/yarn"
