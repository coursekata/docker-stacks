ARG REPO=ghcr.io/coursekata
ARG BASE_TAG=python-3.10

# WORKAROUND: this is required because 'COPY --from' does not support ARGs
# https://github.com/moby/buildkit/issues/2412
# https://github.com/moby/buildkit/pull/3551
FROM ${REPO}/r-notebook:${BASE_TAG} as r

FROM ${REPO}/python-notebook:${BASE_TAG}
LABEL maintainer="CourseKata <tech@coursekata.org>"

# ensure errors get piped
# https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER ${NB_UID}
WORKDIR ${HOME}

# install the built R packages
COPY --from=r "${R_HOME}" "${R_HOME}"
