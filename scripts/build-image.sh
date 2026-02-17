#!/usr/bin/env bash

set -euo pipefail

# Terminal formatting
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'
DIM='\033[2m'

show_help() {
  cat <<EOF
${BOLD}Build a single-architecture Docker image locally${RESET}

This script emulates the docker/build-push-action used in the GitHub Actions
workflow (.github/workflows/build-test-push.yml). It builds locally without
pushing to a registry.

${BOLD}${UNDERLINE}Usage${RESET}
  $0 --image IMAGE --platform PLATFORM [OPTIONS]

${BOLD}${UNDERLINE}Required Parameters${RESET}
  ${BOLD}--image${RESET} IMAGE          Image name to build (corresponds to a Pixi environment)
  ${BOLD}--platform${RESET} PLATFORM    Platform to build for (linux/amd64 or linux/arm64)

${BOLD}${UNDERLINE}Optional Parameters${RESET}
  ${BOLD}--tag${RESET} TAG              Image tag (default: docker-stacks-IMAGE)
  ${BOLD}--target${RESET} TARGET        Target layer to build
  ${BOLD}--build-args${RESET} ARGS      Build arguments to pass to the image
  ${BOLD}--cache-from${RESET} SRC       Additional cache source (can be specified multiple times)
  ${BOLD}-h, --help${RESET}             Show this help message

${BOLD}${UNDERLINE}Default Behavior${RESET}
  If --tag is not specified, images are tagged as ${BOLD}docker-stacks-IMAGE${RESET}
  ${DIM}Example: --image datascience-notebook → docker-stacks-datascience-notebook${RESET}

${BOLD}${UNDERLINE}Cache Behavior${RESET}
  The --cache-from option can be used to specify additional cache sources. However, some are
  automatically included to match the GitHub Actions workflow behavior. If DS_OWNER is set,
  the following cache sources are automatically added:
    - {DS_OWNER}/{IMAGE}:latest
    - {DS_OWNER}/{IMAGE}:cache-{PLATFORM}

  ${DIM}Example with DS_OWNER=ghcr.io/coursekata:${RESET}
    ${DIM}Automatic: type=registry,ref=ghcr.io/coursekata/datascience-notebook:latest${RESET}
    ${DIM}Automatic: type=registry,ref=ghcr.io/coursekata/datascience-notebook:cache-amd64${RESET}

${BOLD}${UNDERLINE}Examples${RESET}
  ${DIM}# Build datascience-notebook for amd64${RESET}
  $0 --image datascience-notebook --platform linux/amd64

  ${DIM}# Build with specific target layer${RESET}
  $0 --image r-notebook --platform linux/arm64 --target base

  ${DIM}# Build with build arguments${RESET}
  $0 --image essentials-notebook --platform linux/amd64 --build-args "ARG1=value1"
EOF
  exit 0
}

# Parse command line arguments
IMAGE=""
PLATFORM=""
TAG=""
TARGET=""
BUILD_ARGS=""
USER_CACHE_FROM_ARGS=()

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
  --target)
    TARGET="$2"
    shift 2
    ;;
  --build-args)
    BUILD_ARGS="$2"
    shift 2
    ;;
  --cache-from)
    USER_CACHE_FROM_ARGS+=("$2")
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

# Validate platform
if [[ "$PLATFORM" != "linux/amd64" && "$PLATFORM" != "linux/arm64" ]]; then
  echo "Error: Platform '$PLATFORM' is not supported. Only linux/amd64 and linux/arm64 are supported."
  exit 1
fi

# Get GitHub token from environment or gh CLI
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  if command -v gh &>/dev/null; then
    GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
    if [[ -z "$GITHUB_TOKEN" ]]; then
      echo "Error: GitHub token not available. Private dependencies will fail to install."
      echo "  Authenticate with: gh auth login"
      echo "  Or set GITHUB_TOKEN environment variable"
      exit 1
    fi
  else
    echo "Error: gh CLI not found and GITHUB_TOKEN not set."
    echo "  Install gh CLI: https://cli.github.com/"
    echo "  Or set GITHUB_TOKEN environment variable"
    exit 1
  fi
fi
export GITHUB_TOKEN

# Determine platform tag for cache naming
if [[ "$PLATFORM" == "linux/amd64" ]]; then
  PLATFORM_TAG="amd64"
else
  PLATFORM_TAG="arm64"
fi

# Construct cache-from arguments automatically (matches GHA workflow behavior)
# Uses DS_OWNER env var if set (e.g., from justfile)
CACHE_FROM_ARGS=()

if [[ -n "${DS_OWNER:-}" ]]; then
  CACHE_FROM_ARGS+=(
    --cache-from "type=registry,ref=$DS_OWNER/$IMAGE:latest"
    --cache-from "type=registry,ref=$DS_OWNER/$IMAGE:cache-$PLATFORM_TAG"
  )
fi

# Append user-provided cache sources
for cache_src in "${USER_CACHE_FROM_ARGS[@]}"; do
  CACHE_FROM_ARGS+=(--cache-from "$cache_src")
done

# Build Docker image using array for proper argument handling
BUILD_CMD=(docker buildx build)

if [[ -n "$TARGET" ]]; then
  BUILD_CMD+=(--target "$TARGET")
fi

BUILD_CMD+=(--platform "$PLATFORM")

# Add PIXI_ENV build argument
BUILD_CMD+=(--build-arg "PIXI_ENV=$IMAGE")

if [[ -n "$BUILD_ARGS" ]]; then
  BUILD_CMD+=(--build-arg "$BUILD_ARGS")
fi

# Add GitHub token secret (required)
BUILD_CMD+=(--secret "id=github_token,env=GITHUB_TOKEN")

# Add cache-from arguments
BUILD_CMD+=("${CACHE_FROM_ARGS[@]}")

BUILD_CMD+=(--tag "${TAG:-docker-stacks-${IMAGE}}")
BUILD_CMD+=(--provenance=false)
BUILD_CMD+=(--load)
BUILD_CMD+=(.)

echo "${BUILD_CMD[*]}"

"${BUILD_CMD[@]}"
