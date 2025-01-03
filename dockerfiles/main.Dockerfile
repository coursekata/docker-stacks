# Customization
ARG DEFAULT_KERNEL=ir
ARG PARENT=ghcr.io/coursekata/foundation

# Pixi settings
ARG PIXI_ENV=ckcode
ARG PIXI_VERSION=0.39.2
ARG PIXI_DIR=/opt/pixi

# Ubuntu 24.04 (noble)
# https://hub.docker.com/_/ubuntu/tags?page=1&name=noble
ARG ROOT_IMAGE=ubuntu:24.04
ARG ROOT_CODENAME=noble

# -----------------------------------------------------------------------------
# Base image with common dependencies
# -----------------------------------------------------------------------------
FROM ${PARENT} AS base


# -----------------------------------------------------------------------------
# Build the dependencies
# -----------------------------------------------------------------------------
# https://ghcr.io/prefix-dev/pixi
FROM ghcr.io/prefix-dev/pixi:${PIXI_VERSION}-${ROOT_CODENAME} AS pixi
FROM base AS build
COPY --from=pixi /usr/local/bin/pixi /usr/local/bin/pixi

ARG PIXI_DIR PIXI_ENV
WORKDIR ${PIXI_DIR}
COPY pixi.toml pixi.lock scripts/setup-env.sh ./
RUN --mount=type=cache,target=/tmp/pixi-cache,sharing=locked,uid=${NB_UID} \
    PIXI_CACHE_DIR=/tmp/pixi-cache \
    pixi install --frozen -e "${PIXI_ENV}"

USER root
RUN PIXI_ENV=${PIXI_ENV} ./setup-env.sh
USER ${NB_USER}


# -----------------------------------------------------------------------------
# Final image
# -----------------------------------------------------------------------------
FROM base AS final

ARG PIXI_DIR PIXI_ENV
ENV CONDA_DIR="${PIXI_DIR}/.pixi/envs/${PIXI_ENV}"
ENV R_HOME="${CONDA_DIR}/lib/R"
ENV _R_SHLIB_STRIP_=true

# copy and setup the packages installed in the build stage
COPY --from=build "${CONDA_DIR}" "${CONDA_DIR}"
COPY --from=build /usr/local/bin/before-notebook.d /usr/local/bin/before-notebook.d
COPY --from=build /usr/local/bin/wrapper.sh /usr/local/bin/wrapper.sh
SHELL ["/usr/local/bin/wrapper.sh", "/bin/bash", "-o", "pipefail", "-c"]

# configure C++ compilers for cmdstan
ENV CXX="clang++"
ENV TBB_CXX_TYPE="clang"

# configure R and Jupyter
ENV PPM="https://p3m.dev/cran/__linux__/${ROOT_CODENAME}/latest"
COPY --chown=${NB_UID}:${NB_GID} assets/Rprofile.site "${R_HOME}/etc/"
RUN --mount=type=bind,source="scripts/install-packages.r",target=/tmp/requirements.r \
    --mount=type=secret,id=GITHUB_TOKEN,env=GITHUB_PAT \
    # ensure all R packages are installed
    R_REMOTES_UPGRADE="never" Rscript /tmp/requirements.r -e "${PIXI_ENV}" && \
    # configure Jupyter
    jupyter server --generate-config && \
    jupyter lab clean && \
    rm -rf "${HOME}/.cache/yarn" && \
    fix-permissions "${HOME}"

ARG DEFAULT_KERNEL
ENV DEFAULT_KERNEL="${DEFAULT_KERNEL}"
