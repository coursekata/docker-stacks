#!/bin/bash

set -e

echo "Building python-notebook"
docker buildx build python-notebook \
  --build-arg PYTHON_VERSION=3.10 \
  --build-arg BUILD_LAB=false \
  --platform linux/amd64 \
  -t coursekata/python-notebook:test \
  "${@}"

echo "Building minimal-r-notebook"
docker buildx build minimal-r-notebook \
  --build-arg PYTHON_VERSION=3.10 \
  --build-arg R_VERSION=4.2 \
  --platform linux/amd64 \
  -t coursekata/minimal-r-notebook:test \
  "${@}"

echo "Building r-notebook"
docker buildx build r-notebook \
  --build-arg BASE_TAG=test \
  --platform linux/amd64 \
  -t coursekata/r-notebook:test \
  "${@}"

echo "Building datascience-notebook"
docker buildx build datascience-notebook \
  --build-arg BASE_TAG=test \
  --build-arg BUILD_LAB=false \
  --platform linux/amd64 \
  -t coursekata/datascience-notebook:test \
  "${@}"