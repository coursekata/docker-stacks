set shell := ["bash", "-cu"]

export DS_OWNER := env("DS_OWNER", "ghcr.io/coursekata")
export GITHUB_TOKEN := env("GITHUB_TOKEN", `gh auth token 2>/dev/null || echo ""`)

CURRENT_ARCH := `uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'`
VALID_ENVS := `pixi info --json | jq -r '[.environments_info[] | select(.name == "default" | not) | .name] | join(" ")'`

# List available recipes
default:
    @just --list

# --- Private helpers ---

# Return tag suffix: ":amd64" for non-native arch, "" for native
[private]
_tag_suffix arch:
    @if [ "{{ arch }}" != "{{ CURRENT_ARCH }}" ]; then echo ":{{ arch }}"; fi

[private]
_build image arch:
    #!/usr/bin/env bash
    set -euo pipefail
    platform="linux/{{ arch }}"
    suffix=$(just _tag_suffix "{{ arch }}")
    ./scripts/build-image.sh --image "{{ image }}" --platform "$platform" --tag "{{ DS_OWNER }}/{{ image }}${suffix}"

# The test image is `final` plus bats and the suite, so building it also
# builds the image under test; there is nothing to mount at run time.
[private]
_test image arch:
    #!/usr/bin/env bash
    set -euo pipefail
    platform="linux/{{ arch }}"
    suffix=$(just _tag_suffix "{{ arch }}")
    tag="{{ DS_OWNER }}/{{ image }}${suffix}-test"
    ./scripts/build-image.sh --image "{{ image }}" --platform "$platform" --target test --tag "$tag"
    docker run --rm --platform="$platform" "$tag"

[private]
_shell image arch: (_build image arch)
    #!/usr/bin/env bash
    set -euo pipefail
    suffix=$(just _tag_suffix "{{ arch }}")
    docker run -it --rm --platform="linux/{{ arch }}" "{{ DS_OWNER }}/{{ image }}${suffix}" bash

[private]
_run image arch:
    #!/usr/bin/env bash
    set -euo pipefail
    suffix=$(just _tag_suffix "{{ arch }}")
    docker run -it --rm --platform="linux/{{ arch }}" -p "${PORT:-8888}:8888" "{{ DS_OWNER }}/{{ image }}${suffix}"

# --- Build ---

# Build image (arch: amd64, arm64; default: native)
[group('build')]
build image arch=CURRENT_ARCH: (_build image arch)

# Build all images (arch: amd64, arm64; default: native)
[group('build')]
build-all arch=CURRENT_ARCH:
    #!/usr/bin/env bash
    set -euo pipefail
    for env in {{ VALID_ENVS }}; do
        just build "$env" "{{ arch }}"
    done

# --- Test ---

# Test image (arch: amd64, arm64; default: native)
[group('test')]
test image arch=CURRENT_ARCH: (_test image arch)

# Test all images (arch: amd64, arm64; default: native)
[group('test')]
test-all arch=CURRENT_ARCH:
    #!/usr/bin/env bash
    set -euo pipefail
    for env in {{ VALID_ENVS }}; do
        just test "$env" "{{ arch }}"
    done

# --- Run ---

# Run container and open shell (builds first; arch: amd64, arm64; default: native)
[group('run')]
shell image arch=CURRENT_ARCH: (_shell image arch)

# Run container with Jupyter (PORT env overrides 8888; arch: amd64, arm64)
[group('run')]
run image arch=CURRENT_ARCH: (_run image arch)

# --- Images ---

# List built images
[group('images')]
img-list:
    @echo "Listing {{ DS_OWNER }} images ..."
    docker images "*{{ DS_OWNER }}/*"

# Remove built images
[group('images')]
img-rm:
    @echo "Removing {{ DS_OWNER }} images ..."
    docker rmi --force $(docker images --quiet "*{{ DS_OWNER }}/*") 2>/dev/null || true

# Remove dangling images
[group('images')]
img-rm-dang:
    @echo "Removing dangling images ..."
    docker rmi --force $(docker images -f "dangling=true" --quiet) 2>/dev/null || true

# Clean all images (dangling + built)
[group('images')]
img-clean: img-rm-dang img-rm

# --- Gate ---

# Lint every shell script the same way CI does
[group('gate')]
lint:
    shellcheck -S warning scripts/*.sh scripts/tests/*.sh scripts/tests/*.bats

# Run a release gate (track: static; the weekly signal stays one command)
[group('gate')]
gate track="static":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ track }}" in
        static) python3 scripts/gate/static.py ;;
        *) echo "unknown gate track: {{ track }}" >&2; exit 1 ;;
    esac
