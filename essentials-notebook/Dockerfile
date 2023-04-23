ARG REPO=ghcr.io/coursekata
ARG BASE_TAG=python-3.10

FROM ${REPO}/base-r-notebook:${BASE_TAG} as base
LABEL maintainer="CourseKata <tech@coursekata.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# r-builder
# -------------------------------------
# Staged installs massively cut down on image size. Once R has built the binaries, it
# doesn't need all of the system dependencies it used to build them, so these can be
# omitted from the final stage.
FROM base as r-builder

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
  /tmp/scripts/setup-r.sh

# hadolint ignore=DL3059
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=bind,from=scripts,target=/tmp/scripts \
  /tmp/scripts/setup-tidyverse.sh

USER ${NB_UID}

# install the full package list, ignoring updates except where required
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  Rscript /tmp/requirements.r


# final
# -------------------------------------
FROM base as final

# install built binaries
COPY --from=r-builder "${R_HOME}" "${R_HOME}"

# set default kernel to use (e.g. for Deepnote)
ENV DEFAULT_KERNEL_NAME=ir
