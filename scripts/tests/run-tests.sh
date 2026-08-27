#!/usr/bin/env bash

set -euo pipefail

# run-tests.sh - Entry point for the bats-core test suite.
# Usage: ./run-tests.sh [environment-name]
#
# The Dockerfile's test stage bakes ENV_NAME in and runs this as the image's
# CMD, so the argument is only needed when invoking the suite by hand.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="${1:-${ENV_NAME:-}}"

if [[ -z "$ENV_NAME" ]]; then
  echo "Error: no environment name given and ENV_NAME is unset"
  echo "Usage: $0 <environment-name>"
  exit 1
fi

export ENV_NAME

# Special case: Set CMDSTAN for datascience-notebook so cmdstanr's library()
# call can find it. Exported (not just assigned) so it reaches the bats
# subprocess and every per-test process bats forks from it.
if [[ "$ENV_NAME" == "datascience-notebook" ]]; then
  export CMDSTAN="${CONDA_DIR}/bin/cmdstan"
fi

BATS="${BATS:-bats}"

# TEST_DEBUG=1 preserves the old debug switch's intent: show what ran, even
# for tests that passed.
bats_flags=()
if [[ "${TEST_DEBUG:-}" == "1" ]]; then
  bats_flags+=(--trace --show-output-of-passing-tests)
fi

# exec so bats' exit code becomes this script's exit code.
exec "$BATS" "${bats_flags[@]}" "$SCRIPT_DIR"
