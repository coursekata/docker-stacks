#!/usr/bin/env bash

# Regenerate pak installer scripts from rpixi.toml
# This script is intended to be run as a pre-commit hook to keep
# the pak-scripts/ directory in sync with rpixi.toml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Generate pak scripts
./scripts/rpixi.R pakgen --all -o ./pak-scripts -q

# Stage the generated files if any changed
git add pak-scripts/*.R 2>/dev/null || true
