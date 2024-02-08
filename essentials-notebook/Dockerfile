# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

ARG PARENT_NAME=base-r-notebook
ARG PARENT_IMAGE=${REGISTRY}/${OWNER}/${PARENT_NAME}

ARG BASE_NAME=base-r-notebook
ARG BASE_IMAGE=${REGISTRY}/${OWNER}/${BASE_NAME}

# build args
ARG PY_REQUIREMENTS=requirements.txt
ARG R_REQUIREMENTS=requirements.r

# cache and build variables (no need to change these)
ARG PIP_CACHE_DIR=/tmp/pip-cache
ARG PIP_WHEEL_DIR=/tmp/pip-wheels
ARG APT_CACHE_DIR=/var/cache/apt
ARG APT_LIB_DIR=/var/lib/apt
ARG SHARED_LIBS_LIST=/tmp/shared-libs.txt


# py-builder
# -------------------------------------
FROM ${PARENT_IMAGE} as py-builder

# make wheels for the Python packages
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" build \
  && pip3 wheel --cache-dir="${PIP_CACHE_DIR}" --wheel-dir="${PIP_WHEEL_DIR}" -r /tmp/requirements.txt


# final
# -------------------------------------
FROM ${BASE_IMAGE} as final
LABEL maintainer="CourseKata <tech@coursekata.org>"
USER ${NB_UID}

ARG R_REQUIREMENTS
RUN --mount=type=cache,target="${CONDA_DIR}/pkgs",uid=${NB_UID},sharing=locked \
  --mount=type=bind,source="${R_REQUIREMENTS}",target=/tmp/requirements.r \
  --mount=type=secret,id=github_token,uid=${NB_UID} \
  # install R packages from conda where possible
  mamba install --yes \
  # "r-testwhat" \
    "r-evaluate" \
    "r-magrittr" \
    "r-markdown" \
    "r-praise" \
    "r-r6" \
    "r-stringdist" \
    "r-xfun" \
  # "r-coursekata" \
    # "r-dslabs" \
    # "r-Lock5withR"
    "r-lsr" \
    "r-metrics" \
    "r-mosaic" \
    "r-palmerpenguins" \
    "r-supernova" \
  "r-fivethirtyeight" \
  "r-ggpubr" \
  "r-gridextra" \
  "r-lme4" \
  "r-plotly" \
  "r-statmod" \
  # set variables for remotes
  && export \
    GITHUB_PAT=$(cat /run/secrets/github_token) \
    R_REMOTES_UPGRADE="never" \
  # pak is required by coursekata, but sometimes has trouble when installed from conda
  && Rscript \
    -e 'repo <- sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch)' \
    -e 'install.packages("pak", repos = repo)' \
  # finish with the full R package install script (it skips packages already installed)
  && Rscript /tmp/requirements.r

# install Python packages from wheels
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  --mount=type=cache,from=py-builder,source="${PIP_WHEEL_DIR}",target="${PIP_WHEEL_DIR}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" --find-links="${PIP_WHEEL_DIR}" \
  -r /tmp/requirements.txt
