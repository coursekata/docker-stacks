#!/bin/bash

set -e

platforms=linux/amd64

echo "Building python-notebook"
docker buildx build python-notebook \
  --build-arg PYTHON_VERSION=3.10 \
  --build-arg BUILD_LAB=false \
  --platform "${platforms}" \
  -t coursekata/python-notebook:test \
  "${@}"

echo "Building minimal-r-notebook"
docker buildx build minimal-r-notebook \
  --build-arg PYTHON_VERSION=3.10 \
  --build-arg R_VERSION=4.2 \
  --platform "${platforms}" \
  -t coursekata/minimal-r-notebook:test \
  "${@}"

echo "Building r-notebook"
docker buildx build r-notebook \
  --build-arg BASE_IMAGE=coursekata/minimal-r-notebook \
  --build-arg BASE_TAG=test \
  --platform "${platforms}" \
  -t coursekata/r-notebook:test \
  "${@}"

echo "Building datascience-notebook"
docker buildx build datascience-notebook \
  --build-arg BASE_IMAGE=coursekata/r-notebook \
  --build-arg BASE_TAG=test \
  --build-arg BUILD_LAB=false \
  --platform "${platforms}" \
  -t coursekata/datascience-notebook:test \
  "${@}"