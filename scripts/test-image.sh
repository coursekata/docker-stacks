#!/usr/bin/env bash

set -euo pipefail

# Terminal formatting
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'
DIM='\033[2m'

show_help() {
  cat <<EOF
${BOLD}Run tests on a locally built Docker image${RESET}

This script runs tests on a Docker image built by build-image.sh. It mounts the
test framework and executes tests inside the container.

${BOLD}${UNDERLINE}Usage${RESET}
  $0 --image IMAGE --platform PLATFORM [OPTIONS]

${BOLD}${UNDERLINE}Required Parameters${RESET}
  ${BOLD}--image${RESET} IMAGE          Image name (valid Pixi environment)
  ${BOLD}--platform${RESET} PLATFORM    Platform to test on (linux/amd64 or linux/arm64)

${BOLD}${UNDERLINE}Optional Parameters${RESET}
  ${BOLD}--tag${RESET} TAG              Image tag to test (default: docker-stacks-IMAGE)
  ${BOLD}-h, --help${RESET}             Show this help message

${BOLD}${UNDERLINE}Default Behavior${RESET}
  If --tag is not specified, tests ${BOLD}docker-stacks-IMAGE${RESET}
  ${DIM}Example: --image datascience-notebook → docker-stacks-datascience-notebook${RESET}

${BOLD}${UNDERLINE}Examples${RESET}
  ${DIM}# Test datascience-notebook on amd64${RESET}
  $0 --image datascience-notebook --platform linux/amd64

  ${DIM}# Test r-notebook on arm64${RESET}
  $0 --image r-notebook --platform linux/arm64
EOF
  exit 0
}

# Parse command line arguments
IMAGE=""
PLATFORM=""
TAG=""

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
  --tag)
    TAG="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
  esac
done

# Validate required arguments
if [[ -z "$IMAGE" ]]; then
  echo "Error: --image is required"
  exit 1
fi

if [[ -z "$PLATFORM" ]]; then
  echo "Error: --platform is required"
  exit 1
fi

# Validate that IMAGE is a valid Pixi environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! "$SCRIPT_DIR/validate-env.sh" "$IMAGE" 2>/dev/null; then
  echo "Error: '$IMAGE' is not a valid Pixi environment"
  echo "Run './scripts/validate-env.sh --help' for more information"
  exit 1
fi

# Generate Python package list on host for testing
PYTHON_PKG_LIST=$(mktemp)
trap 'rm -f "$PYTHON_PKG_LIST"' EXIT
"$SCRIPT_DIR/list-python-packages.sh" "$IMAGE" >"$PYTHON_PKG_LIST" 2>/dev/null || true

# Run tests
echo "Running tests for $IMAGE on $PLATFORM..."

# IMAGE is a validated pixi environment name (no spaces/special chars)
# shellcheck disable=SC2086
docker run --rm --platform="$PLATFORM" \
  --mount=type=bind,source="./scripts",target=/tmp/scripts \
  --mount=type=bind,source="./pixi.toml",target=/home/jovyan/pixi.toml \
  --mount=type=bind,source="./rpixi.toml",target=/home/jovyan/rpixi.toml \
  --mount=type=bind,source="$PYTHON_PKG_LIST",target=/tmp/python-packages.txt,readonly \
  -e PYTHON_PACKAGES_FILE=/tmp/python-packages.txt \
  "${TAG:-docker-stacks-${IMAGE}}" \
  bash /tmp/scripts/tests/run-tests.sh "$IMAGE"
