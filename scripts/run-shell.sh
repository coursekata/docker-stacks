#!/usr/bin/env bash

set -euo pipefail

# Terminal formatting
BOLD=$(tput bold 2>/dev/null || echo '')
UNDERLINE=$(tput smul 2>/dev/null || echo '')
RESET=$(tput sgr0 2>/dev/null || echo '')
DIM=$(tput dim 2>/dev/null || echo '')

show_help() {
  cat <<EOF
${BOLD}Run a bash shell in a Docker container${RESET}

This script runs an interactive bash shell inside a Docker container for
debugging and exploration. The container is automatically removed on exit.

${BOLD}${UNDERLINE}Usage${RESET}
  $0 [OPTIONS]

${BOLD}${UNDERLINE}Options${RESET}
  ${BOLD}--image${RESET} IMAGE          Image to run (default: docker-stacks-notebook)
  ${BOLD}--platform${RESET} PLATFORM    Platform to run on (default: native)
  ${BOLD}-h, --help${RESET}             Show this help message

${BOLD}${UNDERLINE}Examples${RESET}
  ${DIM}# Open a shell in the locally built image${RESET}
  $0

  ${DIM}# Open a shell in a specific architecture${RESET}
  $0 --image test-image:amd64 --platform linux/amd64

  ${DIM}# Open a shell in a remote image${RESET}
  $0 --image ghcr.io/coursekata/datascience-notebook:latest
EOF
  exit 0
}

# Default values
IMAGE="docker-stacks-notebook"
PLATFORM=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
    show_help
    ;;
  --image)
    IMAGE="$2"
    shift 2
    ;;
  --platform)
    PLATFORM="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
  esac
done

# Validate image if it looks like a Pixi environment name
# (i.e., doesn't contain slashes or colons, which indicate registry paths or tags)
if [[ "$IMAGE" != *"/"* && "$IMAGE" != *":"* ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Extract environment name if image follows docker-stacks-* pattern
  if [[ "$IMAGE" == docker-stacks-* ]]; then
    ENV_NAME="${IMAGE#docker-stacks-}"
  else
    ENV_NAME="$IMAGE"
  fi
  if ! "$SCRIPT_DIR/validate-env.sh" "$ENV_NAME" 2>/dev/null; then
    echo "Error: '$ENV_NAME' is not a valid Pixi environment"
    echo "Run './scripts/validate-env.sh --help' for more information"
    exit 1
  fi
fi

# Build docker run command
RUN_CMD=(docker run -it --rm)

if [[ -n "$PLATFORM" ]]; then
  RUN_CMD+=(--platform="$PLATFORM")
fi

RUN_CMD+=("$IMAGE")
RUN_CMD+=(bash)

echo "Opening shell in container..."
echo "Command: ${RUN_CMD[*]}"
echo ""

exec "${RUN_CMD[@]}"
