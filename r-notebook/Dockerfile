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

USER root
ARG APT_CACHE_DIR APT_LIB_DIR
# hadolint ignore=DL3008,DL3009
RUN --mount=type=cache,target="${APT_CACHE_DIR}",sharing=locked \
  --mount=type=cache,target="${APT_LIB_DIR}",sharing=locked \
  apt-get update && apt-get upgrade -y && apt-get -y install --no-install-recommends \
  # install a few pre-compiled packages not on conda
  # note that this is not a robust process --- this will overwrite the R_HOME/site-library if it
  # already exists, and it will not copy over any shared libraries (because these don't need that)
  #
  # ideally, this would be done with conda
  #
  # this also doesn't clean up the superfluous R installation that is added, and instead relies on
  # the multi-stage build to avoid the mess
  r-cran-bigmemory \
  r-cran-mapproj \
  r-cran-mvnfast \
  && mv /usr/lib/R/site-library ${R_HOME}/site-library \
  && chown -R ${NB_UID}:${NB_GID} ${R_HOME}/site-library
USER ${NB_UID}

# install R packages from conda where possible
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "r-av" \
  "r-bayesplot" \
  "r-car" \
  "r-dagitty" \
  "r-emmeans" \
  "r-gganimate" \
  "r-ggdag" \
  # "r-gifski" \
    "rust" \
  "r-here" \
  "r-mapdata" \
  # "r-mapproj" \
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
  "r-rcpptoml" \
  "r-reticulate" \
  # "r-simstudy" \
    "r-bh" \
    # "r-bigmemory" \
    "r-bigmemory.sri" \
    # "r-fastglm" \
    # "r-mvnfast" \
  "r-tidymodels" \
  "r-tidyverse"

# install all other R packages
ARG R_REQUIREMENTS
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true
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
USER ${NB_UID}

# install Python packages from wheels
ARG PIP_CACHE_DIR PIP_WHEEL_DIR PY_REQUIREMENTS
RUN --mount=type=bind,source="${PY_REQUIREMENTS}",target=/tmp/requirements.txt \
  --mount=type=cache,target="${PIP_CACHE_DIR}",uid="${NB_UID}" \
  --mount=type=cache,from=py-builder,source="${PIP_WHEEL_DIR}",target="${PIP_WHEEL_DIR}" \
  pip3 install --disable-pip-version-check --cache-dir="${PIP_CACHE_DIR}" --find-links="${PIP_WHEEL_DIR}" \
  -r /tmp/requirements.txt

# copy over R packages and shared libraries
USER root
ARG SHARED_LIBS_LIST
COPY --from=r-builder --chown=${NB_UID}:${NB_GID} "${R_HOME}/" "${R_HOME}"
RUN --mount=type=cache,from=r-builder,source=/,target=/mounted-r-builder \
  --mount=type=bind,from=new-shared-libs,source="${SHARED_LIBS_LIST}",target="${SHARED_LIBS_LIST}" \
  copy-shared-libs "${SHARED_LIBS_LIST}" /mounted-r-builder /
USER ${NB_UID}

# this is hard to copy over from the r-builder image
RUN Rscript -e 'remotes::install_cran("V8", force = TRUE)'
