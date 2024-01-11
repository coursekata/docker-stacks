#!/bin/bash

set -e

# test that all Python packages are installed
py_output=$(pip show ${@} 2>&1)

# warning output prefix:
warning_prefix="WARNING: Package(s) not found"

py_warning=$(echo "$py_output" | grep "${warning_prefix}" || true)
if echo "$py_output" | grep -q "${warning_prefix}"; then
  echo -e "\033[33m$py_warning\033[0m"
  exit 1
fi
