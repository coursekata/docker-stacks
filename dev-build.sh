#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform=linux/amd64,linux/arm64/v8 
fi
build_lab=${BUILD_LAB:-false}

if [ "${images}" = all ] || [ "${images}" = python-notebook ]; then
  image=python-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    --build-arg PYTHON_VERSION=3.10 \
    --build-arg BUILD_LAB="${build_lab}" \
    --platform "${platform}" \
    -t coursekata/"${image}":test
fi

if [ "${images}" = all ] || [ "${images}" = minimal-r-notebook ] || [ "${images}" = r-notebook ] || [ "${images}" = datascience-notebook ]; then
  image=minimal-r-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    --build-arg PYTHON_VERSION=3.10 \
    --build-arg R_VERSION=4.2 \
    --platform "${platform}" \
    -t coursekata/"${image}":test
fi

if [ "${images}" = all ] || [ "${images}" = r-notebook ] || [ "${images}" = datascience-notebook ]; then
  image=r-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    --build-arg BASE_IMAGE=coursekata/minimal-r-notebook \
    --build-arg BASE_TAG=test \
    --platform "${platform}" \
    -t coursekata/"${image}":test
fi

if [ "${images}" = all ] || [ "${images}" = datascience-notebook ]; then
  image=datascience-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    --build-arg BASE_IMAGE=coursekata/r-notebook \
    --build-arg BASE_TAG=test \
    --build-arg BUILD_LAB="${build_lab}" \
    --platform "${platform}" \
    -t coursekata/"${image}":test
fi
