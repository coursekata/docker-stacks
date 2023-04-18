ARG BASE_IMAGE=ghcr.io/coursekata/minimal-r-notebook
ARG BASE_TAG=r-4.2
FROM ${BASE_IMAGE}:${BASE_TAG} as base

LABEL maintainer="CourseKata <tech@coursekata.org>"

# ensure errors get piped
# https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
  --mount=type=bind,from=scripts,target=/tmp/scripts \
  /tmp/scripts/setup-tidyverse.sh

USER ${NB_UID}

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