ARG PYTHON_VERSION=3.10
FROM jupyter/minimal-notebook:python-${PYTHON_VERSION} as base
ENV PYTHON_VERSION=${PYTHON_VERSION}

LABEL maintainer="CourseKata <tech@coursekata.org>"

# ensure errors get piped
# https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  fonts-dejavu \
  gcc \
  gfortran \
  r-cran-rodbc \
  unixodbc \
  unixodbc-dev

USER ${NB_UID}

# configure R
ENV TZ=Etc/UTC
ENV CRAN=https://packagemanager.rstudio.com/cran/__linux__/jammy/latest
ENV LANG=en_US.UTF-8
ENV _R_SHLIB_STRIP_=true
ENV R_HOME=/opt/conda/lib/R
ENV R_LIBS_USER=/opt/conda/lib/R/library
ENV R_LIBS_SITE=/opt/conda/lib/R/library

# install R and the R kernel
ARG R_VERSION=4.2
ENV R_VERSION=${R_VERSION}
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID} \
  mamba install --yes \
  r-base==${R_VERSION} \
  r-irkernel \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# add R mimetype and networking options
COPY --chown=${NB_UID}:${NB_GID} Rprofile.site "${R_HOME}"/etc/

# set default kernel to use for Jupyter notebooks
ENV DEFAULT_KERNEL_NAME=ir
