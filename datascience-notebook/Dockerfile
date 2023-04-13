ARG BUILD_LAB=true
ARG BASE_TAG=r-4.2
FROM ghcr.io/coursekata/r-notebook:${BASE_TAG} as base

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
  g++

USER ${NB_UID}


# py-builder
# -------------------------------------
# Builds wheels for all of the Python packages used in the final stage. This reduces artifacts from
# building, just like in the r-builder. Putting this in a separate stage as the r-builder allows the
# stages to build concurrently.
FROM base as py-builder

# hadolint ignore=DL3042
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --disable-pip-version-check --cache-dir=/tmp/pip-cache build~=0.10 \
  && pip3 wheel --wheel-dir=/tmp/wheels -r /tmp/requirements.txt


# final-with-lab-build-true
# -------------------------------------
# Installs the Python wheels and builds JupyterLab. This is the production-version of final.
FROM base as final-with-lab-build-true

USER ${NB_UID}
WORKDIR ${HOME}

# hadolint ignore=DL3042
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=cache,from=py-builder,source=/tmp/wheels,target=/tmp/wheels \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --find-links=/tmp/wheels --cache-dir=/tmp/pip-cache -r /tmp/requirements.txt \
  # install jupyter-dash extension (prevents user pop-up on first load)
  && jupyter lab build


# final-without-lab-build-false
# -------------------------------------
# Installs the Python wheels and but doesn't build JupyterLab. This is the dev-version of final.
FROM base as final-with-lab-build-false

USER ${NB_UID}
WORKDIR ${HOME}

# hadolint ignore=DL3042
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=cache,from=py-builder,source=/tmp/wheels,target=/tmp/wheels \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --find-links=/tmp/wheels --cache-dir=/tmp/pip-cache -r /tmp/requirements.txt


# final
# -------------------------------------
FROM final-with-lab-build-${BUILD_LAB} as final
