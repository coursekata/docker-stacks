#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform="linux/amd64,linux/arm64/v8"
fi

org="ghcr.io/coursekata"
tag="test"

with-margin() {
  echo ""
  "${@}"
  echo ""
}

image=base-r-notebook
with-margin echo "Building ${image}"
docker buildx build "${image}" \
  -t "${org}/${image}":test \
  --platform "${platform}" \
  --build-context scripts=scripts \
  --build-arg PYTHON_VERSION=3.10 \
  --build-arg R_VERSION=4.2
with-margin docker images "${org}/${image}:${tag}"

dependents=("all" "essentials-builder" "essentials-notebook" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-builder
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:${tag}" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg ORG=${org} \
    --build-arg BASE_TAG=${tag}
  with-margin docker images "${org}/${image}:${tag}"
fi

dependents=("all" "essentials-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:${tag}" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg ORG=${org} \
    --build-arg BASE_TAG=${tag}
  with-margin docker images "${org}/${image}:${tag}"
fi

dependents=("all" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=r-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:${tag}" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg ORG=${org} \
    --build-arg BASE_TAG=${tag}
  with-margin docker images "${org}/${image}:${tag}"
fi

dependents=("all" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=datascience-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:${tag}" \
    --platform "${platform}" \
    --build-arg ORG=${org} \
    --build-arg BASE_TAG=${tag}
  with-margin docker images "${org}/${image}:${tag}"
fi
