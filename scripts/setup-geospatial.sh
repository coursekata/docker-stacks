#!/bin/bash

set -e

apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  gdal-bin \
  lbzip2 \
  libfftw3-dev \
  libgdal-dev \
  libgeos-dev \
  libgsl0-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libhdf4-alt-dev \
  libhdf5-dev \
  libjq-dev \
  libpq-dev \
  libproj-dev \
  libprotobuf-dev \
  libnetcdf-dev \
  libsqlite3-dev \
  libssl-dev \
  libudunits2-dev \
  lsb-release \
  netcdf-bin \
  postgis \
  protobuf-compiler \
  sqlite3 \
  tk-dev \
  unixodbc-dev
  