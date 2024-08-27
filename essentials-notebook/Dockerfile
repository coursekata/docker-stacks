# syntax = docker/dockerfile:latest
# hadolint shell=bash

# image args
ARG REGISTRY=ghcr.io
ARG OWNER=coursekata
ARG PARENT_NAME=base-r-notebook
ARG PARENT_IMAGE=${REGISTRY}/${OWNER}/${PARENT_NAME}

# build args
ARG CONDA_ENVIRONMENT=environment.yaml
ARG R_REQUIREMENTS=requirements.r


# final
# -------------------------------------
FROM ${PARENT_IMAGE} AS final
LABEL maintainer="CourseKata <tech@coursekata.org>"
USER ${NB_UID}

# install Python packages and any R packages on conda
ARG CONDA_ENVIRONMENT
RUN --mount=type=bind,source="${CONDA_ENVIRONMENT}",target=/tmp/environment.yaml \
  mamba env update -q --name=base --file=/tmp/environment.yaml \
  && mamba install libsqlite --yes --force-reinstall \
  && mamba clean --all -f -y \
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# install R packages
ARG R_REQUIREMENTS
RUN --mount=type=bind,source="${R_REQUIREMENTS}",target=/tmp/requirements.r \
  --mount=type=secret,id=github_token,uid=${NB_UID} \
  GITHUB_PAT=$(cat /run/secrets/github_token) R_REMOTES_UPGRADE="never" \
  Rscript /tmp/requirements.r
