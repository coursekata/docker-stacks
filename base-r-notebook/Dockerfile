# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

# env args baked into image
ARG PYTHON_VERSION=3.12
ARG R_VERSION=4.3
ARG DEFAULT_KERNEL_NAME=ir

# cache and build variables (no need to change these)
ARG APT_CACHE_DIR=/var/cache/apt
ARG APT_LIB_DIR=/var/lib/apt


# final
# -------------------------------------
ARG PARENT_IMAGE=quay.io/jupyter/minimal-notebook:python-${PYTHON_VERSION}
FROM ${PARENT_IMAGE} AS final
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# R system dependencies
USER root
ARG APT_CACHE_DIR APT_LIB_DIR
# hadolint ignore=DL3008,DL3009
RUN --mount=type=cache,target="${APT_CACHE_DIR}",sharing=locked \
  --mount=type=cache,target="${APT_LIB_DIR}",sharing=locked \
  apt-get update && apt-get -y install --no-install-recommends \
    fonts-dejavu \
    gcc \
    gfortran \
    r-cran-rodbc \
    unixodbc \
    unixodbc-dev \
  # cross-platform building sometimes affects the .cache (e.g., adding a rosetta cache)
  && rm -rf "/home/${NB_USER}/.cache/rosetta"  \
  && mkdir -p "/home/${NB_USER}/.cache" \
  && chown -R ${NB_UID}:${NB_GID} "/home/${NB_USER}/.cache"

USER ${NB_UID}

# re-instate global args and bake into image
ARG PYTHON_VERSION DEFAULT_KERNEL_NAME
ENV PYTHON_VERSION=${PYTHON_VERSION}
ENV DEFAULT_KERNEL_NAME=${DEFAULT_KERNEL_NAME}

# R settings
ARG R_VERSION
ENV R_VERSION=${R_VERSION}
ENV TZ=Etc/UTC
ENV _R_SHLIB_STRIP_=true
ENV R_HOME="${CONDA_DIR}/lib/R"

# R, Jupyter kernel and R package manager
RUN mamba install --yes \
    "r-base=${R_VERSION}.*" \
    "r-irkernel"  \
    "r-remotes" \
    'unixodbc' \
  && mamba clean --all -f -y \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# add R mimetype and networking options
COPY --chown=${NB_UID}:${NB_GID} Rprofile.site "${R_HOME}"/etc/
