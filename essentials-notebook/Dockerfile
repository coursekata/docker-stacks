ARG ORG=ghcr.io/coursekata
ARG BASE_TAG=python-3.10

FROM ${ORG}/base-r-notebook:${BASE_TAG} as base
LABEL maintainer="CourseKata <tech@coursekata.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# r-builder
# -------------------------------------
FROM ${ORG}/essentials-builder:${BASE_TAG} as r-builder


# final
# -------------------------------------
FROM base as final

# install built binaries
COPY --from=r-builder "${R_HOME}" "${R_HOME}"

# set default kernel to use (e.g. for Deepnote)
ENV DEFAULT_KERNEL_NAME=ir
