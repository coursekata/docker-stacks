#!/usr/bin/env bash

set -euo pipefail

# Terminal formatting
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'
DIM='\033[2m'

show_help() {
  cat <<EOF
${BOLD}Run a Docker container interactively${RESET}

This script runs a Docker container with port 8888 exposed (for Jupyter).
The container is automatically removed on exit.

${BOLD}${UNDERLINE}Usage${RESET}
  $0 [OPTIONS]

${BOLD}${UNDERLINE}Options${RESET}
  ${BOLD}--image${RESET} IMAGE          Image to run (default: docker-stacks-notebook)
  ${BOLD}--platform${RESET} PLATFORM    Platform to run on (default: native)
  ${BOLD}--port${RESET} PORT            Port to expose (default: 8888)
  ${BOLD}-h, --help${RESET}             Show this help message

${BOLD}${UNDERLINE}Examples${RESET}
  ${DIM}# Run the locally built image${RESET}
  $0

  ${DIM}# Run a specific architecture${RESET}
  $0 --image test-image:amd64 --platform linux/amd64

  ${DIM}# Run with a different port${RESET}
  $0 --port 9999

  ${DIM}# Run a remote image${RESET}
  $0 --image ghcr.io/coursekata/datascience-notebook:latest
EOF
  exit 0
}

# Default values
IMAGE="docker-stacks-notebook"
PLATFORM=""
PORT="8888"

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
  --port)
    PORT="$2"
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

RUN_CMD+=(-p="${PORT}:8888")
RUN_CMD+=("$IMAGE")

echo "Running container..."
echo "Command: ${RUN_CMD[*]}"
echo ""

exec "${RUN_CMD[@]}"
