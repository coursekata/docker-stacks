ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

# r-builder
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/essentials-builder as r-builder


# py-builder
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/essentials-builder as py-builder

# make wheels for the Python packages
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --disable-pip-version-check --cache-dir=/tmp/pip-cache build~=0.10 \
  && pip3 wheel --wheel-dir=/tmp/wheels -r /tmp/requirements.txt


# final
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/base-r-notebook
LABEL maintainer="CourseKata <tech@coursekata.org>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# install Python packages from wheels
RUN --mount=type=cache,target=/tmp/pip-cache,uid=${NB_UID} \
  --mount=type=cache,from=py-builder,source=/tmp/wheels,target=/tmp/wheels \
  --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
  pip3 install --find-links=/tmp/wheels --cache-dir=/tmp/pip-cache -r /tmp/requirements.txt \
  # install jupyter extensions (prevents user pop-up on first load)
  && jupyter lab build

# install built binaries
COPY --from=r-builder "${R_HOME}" "${R_HOME}"

# set default kernel to use (e.g. for Deepnote)
ENV DEFAULT_KERNEL_NAME=ir
