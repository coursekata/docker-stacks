#!/bin/bash

set -e

image=${1:-base-r-notebook}
platform=${DEV_PLATFORM:-${2:-linux/arm64/v8}}

./dev-build.sh "${image}" "${platform}"
docker run -p 8888:8888 --platform "${platform}" coursekata/"${image}":test
