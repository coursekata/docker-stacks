ARG REGISTRY=ghcr.io
ARG OWNER=coursekata

# r-builder
# -------------------------------------
FROM ${REGISTRY}/${OWNER}/essentials-builder as r-builder

# do as many installs as possible with mamba: faster and ensures deps.
RUN --mount=type=cache,target=${CONDA_DIR}/pkgs,uid=${NB_UID},sharing=locked \
  mamba install --yes \
  "cmdstan" \
  "ffmpeg" \
  "gdal" \
  "pkg-config" \
  "proj" \
  "r-BH" \
  "r-car" \
  "r-checkmate" \
  "r-gert" \
  "r-gganimate" \
  "r-ggdag" \
  "r-ggforce" \
  "r-ggraph" \
  "r-gh" \
  "r-gitcreds" \
  "r-graphlayouts" \
  "r-igraph" \
  "r-here" \
  "r-httr2" \
  "r-ini" \
  "r-mapdata" \
  "r-maps" \
  "r-neuralnet" \
  "r-polyclip" \
  "r-posterior" \
  "r-profvis" \
  "r-psych" \
  "r-rcpptoml" \
  "r-reticulate" \
  "r-tensora" \
  "r-tidygraph" \
  "r-tidymodels" \
  "r-tidyverse" \
  "r-usethis" \
  "r-v8" \
  "r-whisker" \
  # ensure user has full control of package and home dirs
  && fix-permissions "${CONDA_DIR}" \
  && fix-permissions "/home/${NB_USER}"

# https://github.com/conda-forge/geopandas-feedstock/issues/63
ENV PROJ_LIB=${CONDA_DIR}/share/proj

USER ${NB_UID}

# install the full package list, ignoring updates except where required
RUN --mount=type=bind,source=requirements.r,target=/tmp/requirements.r \
  CARGO_NET_GIT_FETCH_WITH_CLI=true Rscript /tmp/requirements.r


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
