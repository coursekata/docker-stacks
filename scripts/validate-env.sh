#!/usr/bin/env bash

set -euo pipefail

# Terminal formatting
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'
DIM='\033[2m'

show_help() {
  cat <<EOF
${BOLD}Validate a Pixi environment name${RESET}

This script checks if a given environment name exists in the Pixi configuration.
It queries the Pixi configuration to get the list of valid environments and
validates the provided name against that list.

${BOLD}${UNDERLINE}Usage${RESET}
  $0 ENVIRONMENT

${BOLD}${UNDERLINE}Arguments${RESET}
  ${BOLD}ENVIRONMENT${RESET}        The Pixi environment name to validate

${BOLD}${UNDERLINE}Options${RESET}
  ${BOLD}-h, --help${RESET}         Show this help message

${BOLD}${UNDERLINE}Examples${RESET}
  ${DIM}# Validate an environment name${RESET}
  $0 datascience-notebook

  ${DIM}# Use in scripts${RESET}
  if $0 r-notebook; then
    echo "Valid environment"
  fi
EOF
  exit 0
}

# Check for help flag
if [[ $# -eq 0 ]] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  show_help
fi

ENV_NAME="$1"

# Get list of valid Pixi environments (excluding default)
VALID_ENVS=$(pixi info --json | jq -r '.environments_info[] | select(.name != "default") | .name')

# Check if the environment name is in the list
if echo "$VALID_ENVS" | grep -q -w "$ENV_NAME"; then
  exit 0
else
  echo "Error: Invalid environment '$ENV_NAME'" >&2
  echo "Valid environments are:" >&2
  echo "  ${VALID_ENVS//$'\n'/$'\n'  }" >&2
  exit 1
fi
