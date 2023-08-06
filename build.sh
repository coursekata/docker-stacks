#!/bin/bash

set -e

images=${1:-all}
platform=${2:-all}
if [ "${platform}" = all ]; then
  platform="linux/amd64,linux/arm64/v8"
fi

org="coursekata"
repo1=${org}
repo2="ghcr.io/${org}"
r_version="4.3"
python_version="3.11"
current_dt=$(gdate -u +'%Y-%m-%dT%H:%M:%S.%3NZ')

with-margin() {
  echo ""
  "${@}"
  echo ""
}

image=base-r-notebook
with-margin echo "Building ${image}"
docker buildx build "${image}" \
  -t "${repo1}/${image}:latest" \
  -t "${repo1}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
  -t "${repo1}/${image}:r-${r_version}" \
  -t "${repo1}/${image}:python-${python_version}" \
  -t "${repo2}/${image}:latest" \
  -t "${repo2}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
  -t "${repo2}/${image}:r-${r_version}" \
  -t "${repo2}/${image}:python-${python_version}" \
  --label "org.opencontainers.image.created=${current_dt}" \
  --label "org.opencontainers.image.description=An image with Jupyter Lab, Python, and R installed, and that's it." \
  --label "org.opencontainers.image.licenses=AGPL-3.0" \
  --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
  --label "org.opencontainers.image.source=https://github.com/${org}/docker-stacks" \
  --label "org.opencontainers.image.title=${image}" \
  --label "org.opencontainers.image.url=https://github.com/${org}/docker-stacks" \
  --label "org.opencontainers.image.version=latest" \
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
    -t "${repo1}/${image}:latest" \
    -t "${repo1}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo1}/${image}:r-${r_version}" \
    -t "${repo1}/${image}:python-${python_version}" \
    -t "${repo2}/${image}:latest" \
    -t "${repo2}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo2}/${image}:r-${r_version}" \
    -t "${repo2}/${image}:python-${python_version}" \
    --label "org.opencontainers.image.created=${current_dt}" \
    --label "org.opencontainers.image.description=A builder notebook for the r- and essentials-notebook images." \
    --label "org.opencontainers.image.licenses=AGPL-3.0" \
    --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
    --label "org.opencontainers.image.source=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.title=${image}" \
    --label "org.opencontainers.image.url=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.version=latest" \
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
    -t "${repo1}/${image}:latest" \
    -t "${repo1}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo1}/${image}:r-${r_version}" \
    -t "${repo1}/${image}:python-${python_version}" \
    -t "${repo2}/${image}:latest" \
    -t "${repo2}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo2}/${image}:r-${r_version}" \
    -t "${repo2}/${image}:python-${python_version}" \
    --label "org.opencontainers.image.created=${current_dt}" \
    --label "org.opencontainers.image.description=An image with all of the R packages used in CourseKata books and CourseKata Jupyter Notebooks." \
    --label "org.opencontainers.image.licenses=AGPL-3.0" \
    --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
    --label "org.opencontainers.image.source=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.title=${image}" \
    --label "org.opencontainers.image.url=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.version=latest" \
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
    -t "${repo1}/${image}:latest" \
    -t "${repo1}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo1}/${image}:r-${r_version}" \
    -t "${repo1}/${image}:python-${python_version}" \
    -t "${repo2}/${image}:latest" \
    -t "${repo2}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo2}/${image}:r-${r_version}" \
    -t "${repo2}/${image}:python-${python_version}" \
    --label "org.opencontainers.image.created=${current_dt}" \
    --label "org.opencontainers.image.description=All of the CourseKata essentials with the addition of more instructor-requested R packages." \
    --label "org.opencontainers.image.licenses=AGPL-3.0" \
    --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
    --label "org.opencontainers.image.source=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.title=${image}" \
    --label "org.opencontainers.image.url=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.version=latest" \
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
    -t "${repo1}/${image}:latest" \
    -t "${repo1}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo1}/${image}:r-${r_version}" \
    -t "${repo1}/${image}:python-${python_version}" \
    -t "${repo2}/${image}:latest" \
    -t "${repo2}/${image}:sha-$(git rev-parse --short=8 HEAD)" \
    -t "${repo2}/${image}:r-${r_version}" \
    -t "${repo2}/${image}:python-${python_version}" \
    --label "org.opencontainers.image.created=${current_dt}" \
    --label "org.opencontainers.image.description=All of the CourseKata essentials and R packages with some Python datascience on top." \
    --label "org.opencontainers.image.licenses=AGPL-3.0" \
    --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
    --label "org.opencontainers.image.source=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.title=${image}" \
    --label "org.opencontainers.image.url=https://github.com/${org}/docker-stacks" \
    --label "org.opencontainers.image.version=latest" \
    --platform "${platform}" \
    --build-context scripts=scripts \
    --build-arg BASE_TAG="sha-$(git rev-parse --short=8 HEAD)"
  with-margin docker images "${org}/${image}:sha-$(git rev-parse --short=8 HEAD)"
fi
