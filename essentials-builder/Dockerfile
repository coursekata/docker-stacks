ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

FROM ${REGISTRY}/${OWNER}/base-r-notebook
LABEL maintainer="CourseKata <tech@coursekata.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# compilers
# hadolint ignore=DL3059
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  # av
  cargo \
  # cmdstanr
  g++ \
  # nloptr
  cmake

USER ${NB_UID}

# install R packages from conda where possible
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "r-fivethirtyeight" \
  "r-ggpubr" \
  "r-gridextra" \
  "r-lme4" \
  "r-lsr" \
  "r-markdown" \
  "r-metrics" \
  "r-minqa" \
  "r-mosaic" \
  "r-nloptr" \
  "r-pak" \
  "r-palmerpenguins" \
  "r-plotly" \
  "r-praise" \
  "r-rcppeigen" \
  "r-statmod" \
  "r-stringdist" \
  # ensure user has full control of package and home dirs
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# install the full R package list, ignoring updates except where required
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  Rscript /tmp/requirements.r
