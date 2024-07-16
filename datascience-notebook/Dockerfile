# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata
ARG PARENT_NAME=r-notebook
ARG PARENT_IMAGE=${REGISTRY}/${OWNER}/${PARENT_NAME}

# build args
ARG PY_REQUIREMENTS=requirements.txt
ARG R_REQUIREMENTS=requirements.r

# cache and build variables (no need to change these)
ARG PIP_CACHE_DIR=/tmp/pip-cache
ARG PIP_WHEEL_DIR=/tmp/pip-wheels
ARG APT_CACHE_DIR=/var/cache/apt
ARG APT_LIB_DIR=/var/lib/apt


# py-builder
# -------------------------------------
FROM ${PARENT_IMAGE} AS py-builder

RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes "gdal" "gxx"

# make wheels for the Python packages
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" build \
  && pip3 wheel --cache-dir="${PIP_CACHE_DIR}" --wheel-dir="${PIP_WHEEL_DIR}" -r /tmp/requirements.txt


# final
# -------------------------------------
FROM ${PARENT_IMAGE} AS base
LABEL maintainer="CourseKata <tech@coursekata.org>"

ARG R_REQUIREMENTS
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  --mount=type=bind,source="${R_REQUIREMENTS}",target=/tmp/requirements.r \
  --mount=type=secret,id=github_token,uid=${NB_UID} \
  # install R packages from conda where possible
  mamba install --yes \
  "cmdstan" \
  "r-brms" \
  "r-cmdstanr" \
  "r-ggstatsplot" \
  # "r-rethinking"
    "r-coda" \
    "r-digest" \
  "r-rstanarm" \
  # install all R packages (skips those already installed)
  && GITHUB_PAT=$(cat /run/secrets/github_token) R_REMOTES_UPGRADE="never" Rscript /tmp/requirements.r

# install Python packages from wheels
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  --mount=type=cache,from=py-builder,source="${PIP_WHEEL_DIR}",target="${PIP_WHEEL_DIR}" \
  --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" --find-links="${PIP_WHEEL_DIR}" \
  -r /tmp/requirements.txt
