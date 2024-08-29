#!/bin/bash

set -e

# Extract packages for given sections from a specified file.
get_packages() {
  local filename=$1
  shift  # remove the filename from the arguments

  local sections=("$@")
  local packages=()

  for section in "${sections[@]}"; do
    section_packages=($(awk -v section="$section" '
    BEGIN { in_section=0 }
    $0 == "[" section "]" { in_section=1; next }
    /^\[.*\]/ { in_section=0 }
    in_section && NF { print $1 }' "$filename"))

    if [ ${#section_packages[@]} -eq 0 ]; then
      echo "Warning: Section '$section' not found or empty in file '$filename'." >&2
    else
      packages+=("${section_packages[@]}")
    fi
  done

  echo "${packages[@]}"
}

# Test Python packages are installed by attempting to show them.
test_python_packages() {
  local py_packages=("$@")
  if [ ${#py_packages[@]} -eq 0 ]; then
    echo "No Python packages to test."
    return 0
  fi

  py_output=$(pip show "${py_packages[@]}" 2>&1 || true)
  warning_prefix="WARNING: Package(s) not found"
  py_warning=$(echo "$py_output" | grep "${warning_prefix}" || true)
  if echo "$py_output" | grep -q "${warning_prefix}"; then
    echo -e "\033[31m$py_warning\033[0m"
    return 1
  else
    echo "All Python packages are installed correctly."
    return 0
  fi
}

# Test R packages by attempting to load them.
test_r_packages() {
  local r_packages=("$@")
  if [ ${#r_packages[@]} -eq 0 ]; then
    echo "No R packages to test."
    return 0
  fi

  # convert R packages into an R array string like "c('package1', 'package2')"
  r_packages_str=$(printf ", '%s'" "${r_packages[@]}")
  r_packages_str="c(${r_packages_str:2})"

  Rscript -e "
    options(warn = 2)

    loader <- function(x) {
      tryCatch({
        suppressPackageStartupMessages(library(x, character.only = TRUE))
      }, error = function(e) {
        cat('Error: Failed to load package ', x, '\n', sep = '')
        stop(e)
      })
    }

    load_all <- function(x) invisible(lapply(x, loader))
    load_all($r_packages_str)
  " || {
      echo "Error: One or more R packages failed to load."
      return 1
    }

  echo "All R packages loaded successfully."
  return 0
}

# Write a header in yellow text.
header() {
  echo -e "\n\033[33m$1\033[0m"
}

# Write a success message in green text.
success() {
  echo -e "\033[32m$1\033[0m"
}


# Main script
# ----------------------------
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <filename> <section1> <section2> ... <sectionN>"
  exit 1
fi

filename=$1
shift  # remove the filename from the arguments

r_sections=()
py_sections=()

# separate section arguments into Python and R
for section in "$@"; do
  if [[ $section == python/* ]]; then
    py_sections+=("$section")
  elif [[ $section == r/* ]]; then
    r_sections+=("$section")
  else
    echo "Warning: Section '$section' does not match 'python/*' or 'r/*'. Ignoring." >&2
  fi
done

header "Checking Bash installation"
bash --version

header "Checking R installation"
R --version

header "Checking Python installation"
python --version

header "Checking JupyterLab installation"
jupyter_error=$(jupyter lab -h 2>&1 > /dev/null)
if [ $? -ne 0 ]; then
  echo "An error occurred while running 'jupyter lab -h':"
  echo "$jupyter_error"
fi
success "JupyterLab is installed correctly!"

header "Gathering packages to test"
py_packages=($(get_packages "$filename" "${py_sections[@]}"))
if [ ${#py_packages[@]} -ne 0 ]; then
  echo "Python packages to be tested:"
  echo "${py_packages[@]}"
else
  echo "No Python packages to test."
fi

echo ""

r_packages=($(get_packages "$filename" "${r_sections[@]}"))
if [ ${#r_packages[@]} -ne 0 ]; then
  echo "R packages to be tested:"
  echo "${r_packages[@]}"
else
  echo "No R packages to test."
fi

header "Starting package tests..."
test_r_packages "${r_packages[@]}" &
r_pid=$!
test_python_packages "${py_packages[@]}" &
py_pid=$!

# wait for both jobs to complete and capture their exit statuses
wait $r_pid
r_test_result=$?
wait $py_pid
py_test_result=$?

# check if either of the tests failed
if [ $r_test_result -ne 0 ] || [ $py_test_result -ne 0 ]; then
  exit 1
else
  success "All tests passed!"
  exit 0
fi
