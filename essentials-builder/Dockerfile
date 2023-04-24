ARG ORG=ghcr.io/coursekata
ARG BASE_TAG=python-3.10

FROM ${ORG}/base-r-notebook:${BASE_TAG}
LABEL maintainer="CourseKata <tech@coursekata.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# do as many installs as possible with mamba: faster and ensures deps.
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  # avoid bug in pak: https://github.com/r-lib/pak/issues/393
  "r-MASS" \
  ## coursekata deps
  "r-gridExtra" \
  "r-lme4" \
  "r-plotly" \
  "r-survival" \
  "r-stringi~=1.7.12" \
  "r-data.table" \
  ## testwhat deps
  "r-stringdist" \
  "r-testthat" \
  # ensure user has full control of package and home dirs
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# dependencies for the rest of the packages not installed by mamba
USER root

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=bind,from=scripts,target=/tmp/scripts \
  /tmp/scripts/setup-tidyverse.sh

USER ${NB_UID}

# install the full package list, ignoring updates except where required
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  Rscript /tmp/requirements.r
