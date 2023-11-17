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

# install the full R package list, ignoring updates except where required
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  Rscript /tmp/requirements.r
