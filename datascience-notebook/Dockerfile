# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata
ARG PARENT_NAME=r-notebook
ARG PARENT_IMAGE=${REGISTRY}/${OWNER}/${PARENT_NAME}

# build args
ARG PY_REQUIREMENTS=requirements.txt

# cache and build variables (no need to change these)
ARG PIP_CACHE_DIR=/tmp/pip-cache
ARG PIP_WHEEL_DIR=/tmp/pip-wheels
ARG APT_CACHE_DIR=/var/cache/apt
ARG APT_LIB_DIR=/var/lib/apt
ARG SHARED_LIBS_LIST=/tmp/shared-libs.txt


# base
# -------------------------------------
FROM ${PARENT_IMAGE} as base

# install cmdstan dependencies
USER root
ARG APT_CACHE_DIR APT_LIB_DIR
RUN --mount=type=cache,target="${APT_CACHE_DIR}",sharing=locked \
  --mount=type=cache,target="${APT_LIB_DIR}",sharing=locked \
  apt-get update && apt-get upgrade -y && apt-get -y install --no-install-recommends \
  g++
USER ${NB_UID}


# py-builder
# -------------------------------------
FROM base as py-builder

RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes "gdal"

# make wheels for the Python packages
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" build \
  && pip3 wheel --cache-dir="${PIP_CACHE_DIR}" --wheel-dir="${PIP_WHEEL_DIR}" -r /tmp/requirements.txt


# final
# -------------------------------------
FROM base
LABEL maintainer="CourseKata <tech@coursekata.org>"

# install cmdstan and related requests
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  # install packages from conda where possible
  mamba install --yes \
  "r-brms" \
  # "r-ggstatsplot" \
    "r-afex" \
    "r-bwstest" \
    "r-desolve" \
    "r-elliptic" \
    "r-ggcorrplot" \
    "r-gmp" \
    "r-ggside" \
    "r-hypergeo" \
    # "r-ksamples" \
    "r-multcompview" \
    # "r-paletteer" \
    "r-pbapply" \
    # "r-pmcmrplus" \
    "r-prismatic" \
    "r-rcppgsl" \
    "r-reshape" \
    "r-rmpfr" \
    # "r-statsexpressions" \
      # "r-bayesfactor" \
      "r-suppdists" \
      # "r-wrs2" \
    "r-zeallot" \
  # "r-rethinking"
    "r-coda" \
    "r-digest" \
  # "r-rstanarm"
  # install all other R packages
  && R_REMOTES_UPGRADE="never" Rscript \
  -e 'stan <- "https://mc-stan.org/r-packages/"' \
  -e 'remotes::install_cran("cmdstanr", repos = c(stan, getOption("repos")), dependencies = TRUE)' \
  -e 'cmdstanr::install_cmdstan()' \
  -e 'remotes::install_cran(c("ggstatsplot", "rstanarm"), upgrade = FALSE)' \
  -e 'remotes::install_github("rmcelreath/rethinking", upgrade = FALSE)'

# install Python packages from wheels
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  --mount=type=cache,from=py-builder,source="${PIP_WHEEL_DIR}",target="${PIP_WHEEL_DIR}" \
  --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" --find-links="${PIP_WHEEL_DIR}" \
  -r /tmp/requirements.txt
