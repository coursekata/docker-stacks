#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform="linux/amd64,linux/arm64/v8"
fi

org="ghcr.io/coursekata"
r_version="4.2"
python_version="3.10"

with-margin() {
  echo ""
  "${@}"
  echo ""
}

image=base-r-notebook
with-margin echo "Building ${image}"
docker buildx build "${image}" \
  -t "${org}/${image}:latest" \
  -t "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
  -t "${org}/${image}:r-${r_version}" \
  -t "${org}/${image}:python-${python_version}" \
  --platform "${platform}" \
  --build-context scripts=scripts \
  --build-arg PYTHON_VERSION=${python_version} \
  --build-arg R_VERSION=${r_version}
with-margin docker images "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)"

dependents=("all" "essentials-builder" "essentials-notebook" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-builder
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:latest" \
    -t "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${org}/${image}:r-${r_version}" \
    -t "${org}/${image}:python-${python_version}" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg BASE_TAG="sha-$(git rev-parse --short=8 HEAD)"
  with-margin docker images "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)"
fi

dependents=("all" "essentials-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=essentials-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:latest" \
    -t "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${org}/${image}:r-${r_version}" \
    -t "${org}/${image}:python-${python_version}" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg BASE_TAG="sha-$(git rev-parse --short=8 HEAD)"
  with-margin docker images "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)"
fi

dependents=("all" "r-notebook" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=r-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:latest" \
    -t "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${org}/${image}:r-${r_version}" \
    -t "${org}/${image}:python-${python_version}" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg BASE_TAG="sha-$(git rev-parse --short=8 HEAD)"
  with-margin docker images "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)"
fi

dependents=("all" "datascience-notebook")
if [[ " ${dependents[*]} " =~ (^|[[:space:]])${images}($|[[:space:]]) ]]; then
  image=datascience-notebook
  with-margin echo "Building ${image}"
  docker buildx build "${image}" \
    -t "${org}/${image}:latest" \
    -t "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${org}/${image}:r-${r_version}" \
    -t "${org}/${image}:python-${python_version}" \
    --platform "${platform}" \
    --build-arg BASE_TAG="sha-$(git rev-parse --short=8 HEAD)"
  with-margin docker images "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)"
fi
