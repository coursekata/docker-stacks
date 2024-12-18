# Customization
ARG DEFAULT_KERNEL=ir

# Ubuntu 24.04 (noble)
# https://hub.docker.com/_/ubuntu/tags?page=1&name=noble
ARG ROOT_IMAGE=ubuntu:24.04
ARG ROOT_CODENAME=noble

# Pixi settings
ARG PIXI_ENV=default
ARG PIXI_VERSION=0.39.2
ARG PIXI_DIR=/opt/pixi


# -----------------------------------------------------------------------------
# Base image with common dependencies
# -----------------------------------------------------------------------------
FROM ${ROOT_IMAGE} AS base

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update --yes && \
    # - `apt-get upgrade` is run to patch known vulnerabilities in system packages
    #   as the Ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # Common useful utilities
    curl \
    git \
    nano-tiny \
    sudo \
    tzdata \
    unzip \
    vim-tiny \
    wget \
    # - `ca-certificates` is needed for HTTPS
    ca-certificates \
    # - Add necessary fonts for matplotlib/seaborn
    #   See https://github.com/jupyter/docker-stacks/pull/380 for details
    fonts-liberation \
    # `less` is needed to run help in R
    # see: https://github.com/jupyter/docker-stacks/issues/1588
    less \
    # - `locales` is needed for adjusting locale settings for dates, numbers, etc.
    locales \
    # - `netbase` provides /etc/{protocols,rpc,services}, part of POSIX
    #   and required by various C functions like getservbyname and getprotobyname
    #   https://github.com/jupyter/docker-stacks/pull/2129
    netbase \
    # git-over-ssh
    openssh-client \
    # - `pandoc` is used to convert notebooks to html files
    #   it's not present in the aarch64 Ubuntu image, so we install it here
    pandoc \
    # - `run-one` - a wrapper script that runs no more
    #   than one unique instance of some command with a unique set of arguments,
    #   we use `run-one-constantly` to support the `RESTARTABLE` option
    run-one \
    # `nbconvert` dependencies
    # https://nbconvert.readthedocs.io/en/latest/install.html#installing-tex
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-plain-generic \
    # - `tini` is installed as a helpful container entrypoint,
    #   that reaps zombie processes and such of the actual executable we want to start
    #   See https://github.com/krallin/tini#why-tini for details
    tini \
    # Enable clipboard on Linux host systems
    xclip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # set the locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "C.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    # create alternative for nano -> nano-tiny
    update-alternatives --install /usr/bin/nano nano /bin/nano-tiny 10

# Utility for giving the user appropriate file permissions recursively
# https://quay.io/jupyter/docker-stacks-foundation
COPY --from=quay.io/jupyter/docker-stacks-foundation /usr/local/bin/fix-permissions /usr/local/bin/

# configure environment
ENV SHELL=/bin/bash \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8
ENV NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    HOME="/home/${NB_USER}"

# setup user
RUN if grep -q "${NB_UID}" /etc/passwd; then \
    userdel --remove $(id -un "${NB_UID}"); \
    fi && \
    echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" --no-user-group "${NB_USER}" && \
    chmod g+w /etc/passwd && \
    fix-permissions /home

# HEALTHCHECK documentation: https://docs.docker.com/engine/reference/builder/#healthcheck
# This healtcheck works well for `lab`, `notebook`, `nbclassic`, `server`, and `retro` jupyter
# https://github.com/jupyter/docker-stacks/issues/915#issuecomment-1068528799
HEALTHCHECK --interval=3s --timeout=1s --start-period=3s --retries=3 \
    CMD /etc/jupyter/docker_healthcheck.py || exit 1
# https://quay.io/jupyter/base-notebook
COPY --from=quay.io/jupyter/base-notebook \
    /etc/jupyter/docker_healthcheck.py \
    /etc/jupyter/

# server configuration
ENV JUPYTER_PORT=8888
EXPOSE $JUPYTER_PORT
COPY --from=quay.io/jupyter/base-notebook \
    /etc/jupyter/jupyter_server_config.py \
    /etc/jupyter/

# container startup
CMD ["start-notebook.py"]
# create dirs for startup hooks
RUN mkdir /usr/local/bin/start-notebook.d && \
    mkdir /usr/local/bin/before-notebook.d
# https://quay.io/jupyter/base-notebook
COPY --from=quay.io/jupyter/base-notebook \
    /usr/local/bin/run-hooks.sh \
    /usr/local/bin/start.sh \
    /usr/local/bin/start-notebook.py \
    /usr/local/bin/start-notebook.sh \
    /usr/local/bin/start-singleuser.py \
    /usr/local/bin/start-singleuser.sh \
    /usr/local/bin/

# container entrypoint
ENTRYPOINT ["tini", "-g", "--", "start.sh"]

# switch to the user to prevent accidental container runs as root
USER ${NB_UID}
WORKDIR "${HOME}"
# setup work directory for backward-compatibility
RUN mkdir "${HOME}/work"


# -----------------------------------------------------------------------------
# Build the dependencies
# -----------------------------------------------------------------------------
FROM ghcr.io/prefix-dev/pixi:${PIXI_VERSION}-${ROOT_CODENAME} AS pixi
FROM base AS build
# https://ghcr.io/prefix-dev/pixi
COPY --from=pixi /usr/local/bin/pixi /usr/local/bin/pixi

# install dependencies with pixi
ARG PIXI_DIR PIXI_ENV
WORKDIR ${PIXI_DIR}
COPY pixi.toml pixi.lock ./
RUN --mount=type=cache,target=/tmp/pixi-cache,sharing=locked,uid=${NB_UID} \
    PIXI_CACHE_DIR=/tmp/pixi-cache pixi install --locked -e "${PIXI_ENV}"

USER root

# create script to activate the environment
RUN echo "#!/bin/bash" > /usr/local/bin/before-notebook.d/10activate-env.sh && \
    pixi shell-hook -e ${PIXI_ENV} >> /usr/local/bin/before-notebook.d/10activate-env.sh && \
    chmod +x /usr/local/bin/before-notebook.d/10activate-env.sh

# create shell wrapper that activates the environment
RUN echo "#!/bin/bash" > /usr/local/bin/wrapper.sh && \
    pixi shell-hook -e ${PIXI_ENV} >> /usr/local/bin/wrapper.sh && \
    echo "exec \"\$@\"" >> /usr/local/bin/wrapper.sh && \
    chmod +x /usr/local/bin/wrapper.sh

USER ${NB_UID}


# -----------------------------------------------------------------------------
# Final image
# -----------------------------------------------------------------------------
FROM base AS final

ARG PIXI_ENV
LABEL org.coursekata.image.authors="tech@coursekata.org"
LABEL org.coursekata.image.ref.name="coursekata/${PIXI_ENV}"

ARG PIXI_DIR
ENV CONDA_DIR="${PIXI_DIR}/.pixi/envs/${PIXI_ENV}"
ENV R_HOME="${CONDA_DIR}/lib/R"\
    TZ=Etc/UTC \
    _R_SHLIB_STRIP_=true

# copy and setup the packages installed in the build stage
COPY --from=build "${CONDA_DIR}" "${CONDA_DIR}"
COPY --from=build /usr/local/bin/before-notebook.d /usr/local/bin/before-notebook.d
COPY --from=build /usr/local/bin/wrapper.sh /usr/local/bin/wrapper.sh
SHELL ["/usr/local/bin/wrapper.sh", "/bin/bash", "-o", "pipefail", "-c"]

# configure R and Jupyter
COPY --chown=${NB_UID}:${NB_GID} Rprofile.site "${R_HOME}/etc/"
RUN jupyter server --generate-config && \
    jupyter lab clean && \
    rm -rf "${HOME}/.cache/yarn" && \
    fix-permissions "${HOME}"

# ensure all R packages are installed
RUN --mount=type=bind,source="requirements.r",target=/tmp/requirements.r \
    --mount=type=secret,id=github_token,uid=${NB_UID} \
    export GITHUB_PAT=$(cat /run/secrets/github_token) && \
    export R_REMOTES_UPGRADE="never" && \
    Rscript /tmp/requirements.r -e "${PIXI_ENV}"

ARG DEFAULT_KERNEL
ENV DEFAULT_KERNEL="${DEFAULT_KERNEL}"
