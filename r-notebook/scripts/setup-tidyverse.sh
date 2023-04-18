#!/bin/bash

set -e

apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  cmake \
  libxml2-dev \
  libcairo2-dev \
  libgit2-dev \
  default-libmysqlclient-dev \
  libpq-dev \
  libsasl2-dev \
  libsqlite3-dev \
  libssh2-1-dev \
  libxtst6 \
  libcurl4-openssl-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  unixodbc-dev
  