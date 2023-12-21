# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata
ARG BASE_IMAGE=r-notebook

# cache args (no need to change these)
ARG PIP_CACHE_DIR=/tmp/pip-cache
ARG PIP_WHEEL_DIR=/tmp/pip-wheels
ARG APT_CACHE_DIR=/var/cache/apt
ARG APT_LIB_DIR=/var/lib/apt

# build args
ARG PY_REQUIREMENTS=requirements.txt
ARG R_REQUIREMENTS=requirements.r

# global args
ARG DEFAULT_KERNEL_NAME=ir


# py-builder
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/${BASE_IMAGE} as py-builder

USER root

ARG APT_CACHE_DIR APT_LIB_DIR
# hadolint ignore=DL3008,DL3009
RUN --mount=type=cache,target="${APT_CACHE_DIR}",sharing=locked \
  --mount=type=cache,target="${APT_LIB_DIR}",sharing=locked \
  apt-get update && apt-get upgrade -y && apt-get -y install --no-install-recommends \
  g++

USER ${NB_UID}

RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "gdal" \
  "pkg-config" \
  "proj" \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# make wheels for the Python packages
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" build \
  && pip3 wheel --cache-dir="${PIP_CACHE_DIR}" --wheel-dir="${PIP_WHEEL_DIR}" -r /tmp/requirements.txt


# r-builder
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/${BASE_IMAGE} as r-builder


# final
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/base-r-notebook as final
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER ${NB_UID}

# install cmdstan
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes "cmdstan" "cmdstanpy" \
  && Rscript -e 'remotes::install_cran("cmdstanr", repos = "https://mc-stan.org/r-packages/", dependencies = TRUE)' \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# install Python packages from wheels
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  --mount=type=cache,from=py-builder,source="${PIP_WHEEL_DIR}",target="${PIP_WHEEL_DIR}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" --find-links="${PIP_WHEEL_DIR}" \
  -r /tmp/requirements.txt \
  # install jupyter extensions (prevents user pop-up on first load)
  && jupyter lab build \
  # ensure user has full control of package and home dirs
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# copy over R packages
COPY --from=r-builder --chown=${NB_UID}:${NB_GID} ${R_HOME} ${R_HOME}
COPY --from=r-builder --chown=${NB_UID}:${NB_GID} ${CONDA_DIR}/lib/libnlopt* ${CONDA_DIR}/lib

# set default kernel
ARG DEFAULT_KERNEL_NAME
ENV DEFAULT_KERNEL_NAME=${DEFAULT_KERNEL_NAME}
