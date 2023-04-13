ARG BASE_TAG=r-4.2
FROM ghcr.io/coursekata/minimal-r-notebook:${BASE_TAG} as base

LABEL maintainer="CourseKata <tech@coursekata.org>"

# ensure errors get piped
# https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  gdal-bin \
  libgdal-dev \
  libproj-dev

USER ${NB_UID}


# r-builder
# -------------------------------------
# Builds all of the R packages needed in the final image. This stage requires a bunch of
# compilation dependencies that would bloat the final image.
FROM base as r-builder

USER root

# system dependencies for various packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=bind,source=scripts,target=/tmp/scripts \
  /tmp/scripts/setup-av.sh \
  && /tmp/scripts/setup-tidyverse.sh \
  && /tmp/scripts/setup-geospatial.sh

USER ${NB_UID}

# these options are important for installing packages with the builder
# user-facing options should instead go in the Rprofile.site file
# (they are separate from requirements.r to make that file easier to share)
COPY --chown=${NB_UID}:${NB_GID} Rprofile.builder.site "${R_HOME}"/etc/Rprofile.site

# install packages
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  Rscript /tmp/requirements.r


# final
# -------------------------------------
FROM base as final

USER ${NB_UID}
WORKDIR ${HOME}

# install the built R packages
COPY --from=r-builder "${R_HOME}" "${R_HOME}"
