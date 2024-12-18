#!/bin/bash

set -e

$(dirname "$0")/test-packages.sh "$(dirname "$0")/packages.txt" \
  "r/base-r" \
  "r/essentials" \
  "python/essentials" \
  "r/r"
