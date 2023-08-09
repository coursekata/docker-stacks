ARG ORG=ghcr.io/coursekata
ARG BASE_TAG=python-3.11


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


# py-builder
# -------------------------------------
FROM ${ORG}/essentials-builder:${BASE_TAG} as py-builder

# make wheels for the Python packages
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --disable-pip-version-check --cache-dir=/tmp/pip-cache build~=0.10 \
  && pip3 wheel --wheel-dir=/tmp/wheels -r /tmp/requirements.txt


# final
# -------------------------------------
FROM ${ORG}/base-r-notebook:${BASE_TAG}
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# install built binaries
COPY --from=r-builder "${R_HOME}" "${R_HOME}"

# install Python packages from wheels
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=cache,from=py-builder,source=/tmp/wheels,target=/tmp/wheels \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --find-links=/tmp/wheels --cache-dir=/tmp/pip-cache -r /tmp/requirements.txt \
  # install jupyter extensions (prevents user pop-up on first load)
  && jupyter lab build

# set default kernel to use (e.g. for Deepnote)
ENV DEFAULT_KERNEL_NAME=ir
