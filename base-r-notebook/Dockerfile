ARG PYTHON_VERSION=3.10
ARG R_VERSION=4.2

FROM jupyter/minimal-notebook:python-${PYTHON_VERSION} as base
LABEL maintainer="CourseKata <tech@coursekata.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER ${NB_UID}

# re-instate build args and bake into image
ARG R_VERSION
ENV R_VERSION=${R_VERSION}
ARG PYTHON_VERSION
ENV PYTHON_VERSION=${PYTHON_VERSION}

# configure R
ENV TZ=Etc/UTC
ENV LANG=en_US.UTF-8
ENV _R_SHLIB_STRIP_=true
ENV R_HOME=/opt/conda/lib/R

# add R mimetype and networking options
COPY --chown=${NB_UID}:${NB_GID} Rprofile.site "${R_HOME}"/etc/

# base R install with IRkernel
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "pkg-config" \
  "r-base~=${R_VERSION}" \
  "r-irkernel"  \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"
