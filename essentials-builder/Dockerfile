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
  # R packages
  "r-bit" \
  "r-commonmark" \
  "r-curl" \
  "r-data.table" \
  "r-diffobj" \
  "r-digest" \
  "r-dplyr" \
  "r-farver" \
  "r-fs" \
  "r-gridExtra" \
  "r-jsonlite" \
  "r-lattice" \
  "r-lme4" \
  "r-MatrixModels" \
  "r-mgcv" \
  "r-nlme" \
  "r-nloptr" \
  "r-plotly" \
  "r-purrr" \
  "r-Rcpp" \
  "r-RcppEigen" \
  "r-rlang" \
  "r-statmod" \
  "r-stringdist" \
  "r-survival" \
  "r-testthat" \
  "r-vctrs" \
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
