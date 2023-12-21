# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata
ARG BASE_IMAGE=essentials-notebook

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

# make wheels for the Python packages
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" build \
  && pip3 wheel --cache-dir="${PIP_CACHE_DIR}" --wheel-dir="${PIP_WHEEL_DIR}" -r /tmp/requirements.txt


# r-builder
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/${BASE_IMAGE} as r-builder

# install R packages from conda where possible
ARG R_REQUIREMENTS
RUN --mount=type=bind,source="${R_REQUIREMENTS}",target=/tmp/requirements.r \
  --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "ffmpeg" \
  "gdal" \
  "pkg-config" \
  "proj" \
  "rust" \
  "r-bayesplot" \
  "r-BH" \
  "r-car" \
  "r-checkmate" \
  "r-emmeans" \
  "r-gert" \
  "r-gganimate" \
  "r-ggdag" \
  "r-ggforce" \
  "r-ggraph" \
  "r-gh" \
  "r-gitcreds" \
  "r-graphlayouts" \
  "r-igraph" \
  "r-here" \
  "r-httr2" \
  "r-ini" \
  "r-mapdata" \
  "r-maps" \
  "r-neuralnet" \
  "r-polyclip" \
  "r-posterior" \
  "r-profvis" \
  "r-psych" \
  "r-rcpptoml" \
  "r-reticulate" \
  "r-tensora" \
  "r-tidygraph" \
  "r-tidymodels" \
  "r-tidyverse" \
  "r-usethis" \
  "r-v8" \
  "r-whisker" \
  # install all other R packages
  && export CARGO_NET_GIT_FETCH_WITH_CLI=true \
  && Rscript -e 'install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))' \
  && Rscript /tmp/requirements.r \
  # ensure user has full control of package and home dirs
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"


# final
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/base-r-notebook as final
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER ${NB_UID}

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
