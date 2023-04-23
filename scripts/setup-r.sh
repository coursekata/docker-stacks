#!/bin/bash

set -e

apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  fonts-dejavu \
  gcc \
  gfortran \
  libcurl4-openssl-dev \
  pkg-config \
  r-cran-rodbc \
  unixodbc \
  unixodbc-dev
  