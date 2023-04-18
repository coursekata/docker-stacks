#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform=linux/amd64,linux/arm64/v8 
fi
build_lab=${BUILD_LAB:-false}

dependents=("all" "python-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=python-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-arg PYTHON_VERSION=3.10 \
    --build-arg BUILD_LAB="${build_lab}"
fi

dependents=("all" "minimal-r-notebook" "essentials-notebook" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=minimal-r-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-arg PYTHON_VERSION=3.10 \
    --build-arg R_VERSION=4.2
fi

dependents=("all" "essentials-notebook" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg REPO=coursekata \
    --build-arg BASE_TAG=test
fi

dependents=("all" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=r-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg REPO=coursekata \
    --build-arg BASE_TAG=test
fi

dependents=("all" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=datascience-notebook
  echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-arg REPO=coursekata \
    --build-arg BASE_TAG=test \
    --build-arg BUILD_LAB="${build_lab}"
fi
