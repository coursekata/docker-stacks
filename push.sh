#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform="linux/amd64,linux/arm64/v8"
fi

r_version="4.2"
python_version="3.10"

./build.sh "${images}" "${platform}"

images=("base-r-notebook" "essentials-builder" "essentials-notebook" "r-notebook" "datascience-notebook")
for image in "${images[@]}"; do
  docker push coursekata/"${image}":latest
  docker push "coursekata/${image}:sha-$(git rev-parse --short=8 HEAD)"
  docker push "coursekata/${image}:r-${r_version}"
  docker push "coursekata/${image}:python-${python_version}"
  docker push ghcr.io/coursekata/"${image}":latest
  docker push "ghcr.io/coursekata/${image}:sha-$(git rev-parse --short=8 HEAD)"
  docker push "ghcr.io/coursekata/${image}:r-${r_version}"
  docker push "ghcr.io/coursekata/${image}:python-${python_version}"
done
