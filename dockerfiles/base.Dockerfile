# Ubuntu 24.04 (noble)
# https://hub.docker.com/_/ubuntu/tags?page=1&name=noble
ARG ROOT_IMAGE=ubuntu:24.04
ARG ROOT_CODENAME=noble

# -----------------------------------------------------------------------------
# This stage has the basic tools and utilities need to run a minimal Jupyter
# server. It does not include any tools for working in the terminal or nice-to-
# have utilities like `nbconvert`.
# -----------------------------------------------------------------------------
FROM ${ROOT_IMAGE} AS foundation

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
    sudo \
    tzdata \
    unzip \
    wget \
    # - `ca-certificates` is needed for HTTPS
    ca-certificates \
    # `less` is needed to run help in R
    # see: https://github.com/jupyter/docker-stacks/issues/1588
    less \
    # - `locales` is needed for adjusting locale settings for dates, numbers, etc.
    locales \
    # - `netbase` provides /etc/{protocols,rpc,services}, part of POSIX
    #   and required by various C functions like getservbyname and getprotobyname
    #   https://github.com/jupyter/docker-stacks/pull/2129
    netbase \
    # - `run-one` - a wrapper script that runs no more
    #   than one unique instance of some command with a unique set of arguments,
    #   we use `run-one-constantly` to support the `RESTARTABLE` option
    run-one \
    # - `tini` is installed as a helpful container entrypoint,
    #   that reaps zombie processes and such of the actual executable we want to start
    #   See https://github.com/krallin/tini#why-tini for details
    tini && \
    # clean up
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # set the locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "C.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

# Utility for giving the user appropriate file permissions recursively
# https://quay.io/jupyter/docker-stacks-foundation
COPY --from=quay.io/jupyter/docker-stacks-foundation /usr/local/bin/fix-permissions /usr/local/bin/

# configure environment
ARG ROOT_IMAGE ROOT_CODENAME
ENV ROOT_IMAGE=${ROOT_IMAGE} \
    ROOT_CODENAME=${ROOT_CODENAME} \
    SHELL=/bin/bash \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    TZ=Etc/UTC
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
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
# This stage is used to build image foundations that have all the tools and
# utilities that one would expect to find in a typical Jupyter environment.
# Unlike the `foundation` image, this image includes utilities for working in
# the terminal, nbconvert, and other good stuff.
# -----------------------------------------------------------------------------
FROM foundation AS final

USER root

RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # Common useful utilities
    nano-tiny \
    vim-tiny \
    pkg-config \
    # git-over-ssh
    openssh-client \
    # Enable clipboard on Linux host systems
    xclip \
    # - Add necessary fonts for matplotlib/seaborn
    #   See https://github.com/jupyter/docker-stacks/pull/380 for details
    fonts-liberation \
    # - `pandoc` is used to convert notebooks to html files
    pandoc \
    # `nbconvert` dependencies
    # https://nbconvert.readthedocs.io/en/latest/install.html#installing-tex
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-plain-generic && \
    # TODO: do we need these too?
    # https://github.com/jupyter/nbconvert/issues/1328#issuecomment-1768665936
    # clean up apt cache
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # create alternative for nano -> nano-tiny
    update-alternatives --install /usr/bin/nano nano /bin/nano-tiny 10

USER ${NB_UID}
