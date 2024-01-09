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


# final
# -------------------------------------
FROM ${BASE_IMAGE} as final

# setup rust
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
    "gh" \
    "rust" \
    "r-devtools" \
    "r-pkgbuild"

COPY --chmod=777 build.sh /usr/local/bin/build.sh

ENTRYPOINT ["/usr/local/bin/build.sh"]
