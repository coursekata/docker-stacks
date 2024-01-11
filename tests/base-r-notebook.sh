#!/bin/bash

set -e

r_packages=(
  # base
  remotes
  IRkernel
)

py_packages=(
  # base
)

"$(dirname "$0")/test-r-packages.sh" "${r_packages[@]}" & r_pid=$!
for job in $r_pid; do wait $job || exit 1; done
echo -e "\033[32mAll tests passed!\033[0m"
