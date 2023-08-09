ARG ORG=ghcr.io/coursekata
ARG BASE_TAG=python-3.11

# r-builder
# -------------------------------------
FROM ${ORG}/essentials-builder:${BASE_TAG} as r-builder


# py-builder
# -------------------------------------
FROM ${ORG}/essentials-builder:${BASE_TAG} as py-builder

# make wheels for the Python packages
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --disable-pip-version-check --cache-dir=/tmp/pip-cache build~=0.10 \
  && pip3 wheel --wheel-dir=/tmp/wheels -r /tmp/requirements.txt


# final
# -------------------------------------
FROM ${ORG}/base-r-notebook:${BASE_TAG}
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# install built binaries
COPY --from=r-builder "${R_HOME}" "${R_HOME}"

# install Python packages from wheels
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=cache,from=py-builder,source=/tmp/wheels,target=/tmp/wheels \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --find-links=/tmp/wheels --cache-dir=/tmp/pip-cache -r /tmp/requirements.txt \
  # install jupyter extensions (prevents user pop-up on first load)
  && jupyter lab build

# set default kernel to use (e.g. for Deepnote)
ENV DEFAULT_KERNEL_NAME=ir
