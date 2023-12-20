# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

# cache args (no need to change these)
ARG PIP_CACHE_DIR=/tmp/pip-cache
ARG PIP_WHEEL_DIR=/tmp/pip-wheels
ARG APT_CACHE_DIR=/var/cache/apt
ARG APT_LIB_DIR=/var/lib/apt

# global args
ARG PYTHON_VERSION=3.11
ARG R_VERSION=4.3
ARG DEFAULT_KERNEL_NAME=ir


# final
# -------------------------------------
FROM jupyter/minimal-notebook:python-${PYTHON_VERSION} as base
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# re-instate global args and bake into image
ARG R_VERSION PYTHON_VERSION
ENV R_VERSION=${R_VERSION}
ENV PYTHON_VERSION=${PYTHON_VERSION}

USER root

# setup R
ENV TZ=Etc/UTC
ENV LANG=en_US.UTF-8
ENV _R_SHLIB_STRIP_=true
ENV R_HOME="${CONDA_DIR}/lib/R"

ARG APT_CACHE_DIR APT_LIB_DIR
# hadolint ignore=DL3008,DL3009
RUN --mount=type=cache,target="${APT_CACHE_DIR}",sharing=locked \
  --mount=type=cache,target="${APT_LIB_DIR}",sharing=locked \
  apt-get update && apt-get upgrade -y && apt-get -y install --no-install-recommends \
  # for R
  fonts-dejavu \
  gcc \
  gfortran \
  r-cran-rodbc \
  unixodbc \
  unixodbc-dev

USER ${NB_UID}

# install basic R packages
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "r-base~=${R_VERSION}" \
  "r-irkernel"  \
  "r-remotes" \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# add R mimetype and networking options
COPY --chown=${NB_UID}:${NB_GID} Rprofile.site "${R_HOME}"/etc/

# set default kernel
ARG DEFAULT_KERNEL_NAME
ENV DEFAULT_KERNEL_NAME=${DEFAULT_KERNEL_NAME}
