#!/bin/bash

set -e

apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  ffmpeg \
  libavfilter-dev