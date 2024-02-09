# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

ARG PARENT_NAME=essentials-notebook
ARG PARENT_IMAGE=${REGISTRY}/${OWNER}/${PARENT_NAME}

ARG BASE_NAME=base-r-notebook
ARG BASE_IMAGE=${REGISTRY}/${OWNER}/${BASE_NAME}

# build args
ARG PY_REQUIREMENTS=requirements.txt
ARG R_REQUIREMENTS=requirements.r
ARG R_PRECOMPILED_PACKAGES=precompiled

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


# r-builder
# -------------------------------------
FROM ${PARENT_IMAGE} as r-builder

# install R packages from conda where possible
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
    "r-av" \
    "r-bayesplot" \
    "r-broom.mixed" \
    "r-car" \
    "r-dagitty" \
    "r-datapasta" \
    "r-devtools" \
    "r-dharma" \
    # "r-easystats" \
      "r-bayestestr" \
      "r-correlation" \
      "r-datawizard" \
      "r-effectsize" \
      "r-insight" \
      "r-modelbased" \
      "r-parameters" \
      "r-performance" \
      # "r-report" \
      "r-see" \
    "r-emmeans" \
    "r-fs" \
    "r-gganimate" \
    "r-ggdag" \
    "r-ggeffects" \
    "r-gifski" \
    "r-gt" \
    "r-here" \
    "r-janitor" \
    "r-lmertest" \
    "r-loo" \
    "r-mapdata" \
    "r-mapproj" \
    "r-marginaleffects" \
    "r-modelsummary" \
    "r-neuralnet" \
    # "r-ocsdata" \
      "r-credentials" \
      "r-gert" \
      "r-gh" \
      "r-gitcreds" \
      "r-httr2" \
      "r-ini" \
      "r-zip" \
      "r-usethis" \
      "r-whisker" \
    "r-posterior" \
    "r-profvis" \
    "r-psych" \
    "r-purrr" \
    "r-rcpptoml" \
    "r-reticulate" \
    # "r-simstudy" \
      "r-bh" \
      "r-bigmemory" \
      "r-bigmemory.sri" \
      "r-fastglm" \
      "r-mvnfast" \
    "r-tidybayes" \
    "r-tidymodels" \
    "r-tidyverse"

# install all other R packages
ARG R_REQUIREMENTS
RUN --mount=type=bind,source="${R_REQUIREMENTS}",target=/tmp/requirements.r \
  --mount=type=secret,id=github_token,uid=${NB_UID} \
  GITHUB_PAT=$(cat /run/secrets/github_token) \
  R_REMOTES_UPGRADE="never" \
  Rscript /tmp/requirements.r


# pre-shared-libs
# -------------------------------------
FROM ${BASE_IMAGE} as pre-shared-libs
ARG SHARED_LIBS_LIST
RUN find-shared-libs "${R_HOME}/library" > "${SHARED_LIBS_LIST}"


# new-shared-libs
# -------------------------------------
FROM r-builder as new-shared-libs

ARG SHARED_LIBS_LIST
COPY --from=pre-shared-libs "${SHARED_LIBS_LIST}" /tmp/pre-shared-libs.txt
RUN find-shared-libs "${R_HOME}/library" > /tmp/post-shared-libs.txt \
  && find-shared-libs "${R_HOME}/site-library" >> /tmp/post-shared-libs.txt \
  && diff-shared-libs /tmp/pre-shared-libs.txt /tmp/post-shared-libs.txt > "${SHARED_LIBS_LIST}"


# final
# -------------------------------------
FROM ${BASE_IMAGE} as final
LABEL maintainer="CourseKata <tech@coursekata.org>"

# copy over R packages and shared libraries
USER root
ARG SHARED_LIBS_LIST
COPY --from=r-builder --chown=${NB_UID}:${NB_GID} "${R_HOME}/" "${R_HOME}"
RUN --mount=type=cache,from=r-builder,source=/,target=/mounted-r-builder \
  --mount=type=bind,from=new-shared-libs,source="${SHARED_LIBS_LIST}",target="${SHARED_LIBS_LIST}" \
  copy-shared-libs "${SHARED_LIBS_LIST}" /mounted-r-builder /
USER ${NB_UID}

# install Python packages from wheels
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  --mount=type=cache,from=py-builder,source="${PIP_WHEEL_DIR}",target="${PIP_WHEEL_DIR}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" --find-links="${PIP_WHEEL_DIR}" \
  -r /tmp/requirements.txt \
  # this is hard to copy over from the r-builder image
  && Rscript -e 'remotes::install_cran("V8", force = TRUE)'
