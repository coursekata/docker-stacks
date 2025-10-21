#!/usr/bin/env bash

set -euo pipefail

# run-tests.sh - Generic test runner for all CourseKata Docker Stacks environments
# Usage: ./run-tests.sh <environment-name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="${1:-}"

# Validate environment name
if [[ -z "$ENV_NAME" ]]; then
  echo "Error: Environment name required"
  echo "Usage: $0 <environment-name>"
  exit 1
fi

# Note: Environment name is already validated by test-image.sh on the host
# No need to re-validate here (would require pixi/jq which aren't in the container)

# Source test libraries
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/helpers.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/system.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/jupyter.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/packages-python.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/packages-r.sh"

# Special case: Set CMDSTAN for datascience-notebook
if [[ "$ENV_NAME" == "datascience-notebook" ]]; then
  export CMDSTAN="${CONDA_DIR}/bin/cmdstan"
fi

# -----------------------------------------------------------------------------
# Main Test Execution
# -----------------------------------------------------------------------------

# Generate header dynamically
print_header "$ENV_NAME"

# Environment and system tests (fast)
info "Running environment and system tests..."
test_user_setup || true
test_environment_variables || true
test_python_environment || true
test_r_environment || true

echo ""

# Jupyter and kernel tests (fast)
info "Running Jupyter and kernel tests..."
test_jupyter_all || true

echo ""

# Package tests (slower)
info "Running package tests (this may take a few minutes)..."
test_python_packages "$ENV_NAME" || true
test_r_packages "$ENV_NAME" || true

# Final summary
print_final_summary "$ENV_NAME"
exit $?
