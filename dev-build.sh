#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform=linux/amd64,linux/arm64/v8 
fi

with-margin() {
  echo ""
  "${@}"
  echo ""
}

image=base-r-notebook
with-margin echo "Building ${image}"
docker buildx build "${image}" \
  -t coursekata/"${image}":test \
  --platform "${platform}" \
  --build-context scripts=scripts \
  --build-arg PYTHON_VERSION=3.10 \
  --build-arg R_VERSION=4.2
with-margin docker images coursekata/"${image}":test

dependents=("all" "essentials-builder" "essentials-notebook" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-builder
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg ORG=coursekata \
    --build-arg BASE_TAG=test
  with-margin docker images coursekata/"${image}":test
fi

dependents=("all" "essentials-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg ORG=coursekata \
    --build-arg BASE_TAG=test
  with-margin docker images coursekata/"${image}":test
fi

dependents=("all" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=r-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg ORG=coursekata \
    --build-arg BASE_TAG=test
  with-margin docker images coursekata/"${image}":test
fi

dependents=("all" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=datascience-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t coursekata/"${image}":test \
    --platform "${platform}" \
    --build-arg ORG=coursekata \
    --build-arg BASE_TAG=test
  with-margin docker images coursekata/"${image}":test
fi
