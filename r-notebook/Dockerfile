ARG ORG=ghcr.io/coursekata
ARG BASE_TAG=python-3.11

FROM ${ORG}/base-r-notebook:${BASE_TAG} as base
LABEL maintainer="CourseKata <tech@coursekata.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# r-builder
# -------------------------------------
FROM ${ORG}/essentials-builder:${BASE_TAG} as r-builder

# do as many installs as possible with mamba: faster and ensures deps.
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  ## av
  "ffmpeg" \
  ## geospatial
  "gdal" \
  "pkg-config" \
  "proj" \
  "r-gert" \
  "r-units" \
  # ensure user has full control of package and home dirs
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# https://github.com/conda-forge/geopandas-feedstock/issues/63
ENV PROJ_LIB=${CONDA_DIR}/share/proj

# dependencies for the rest of the packages not installed by mamba
USER root

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=bind,from=scripts,target=/tmp/scripts \
  /tmp/scripts/setup-geospatial.sh

# hadolint ignore=DL3059
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=bind,from=scripts,target=/tmp/scripts \
  /tmp/scripts/setup-av.sh

USER ${NB_UID}

# install the full package list, ignoring updates except where required
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  CARGO_NET_GIT_FETCH_WITH_CLI=true Rscript /tmp/requirements.r


# final
# -------------------------------------
FROM base as final

# install built binaries
COPY --from=r-builder "${R_HOME}" "${R_HOME}"

# set default kernel to use (e.g. for Deepnote)
ENV DEFAULT_KERNEL_NAME=ir
