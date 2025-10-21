#!/usr/bin/env bash

# packages-r.sh - R package installation and loading tests
# Tests that all R packages can be loaded with library() without errors

# Source helpers (use local variable to avoid overwriting SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_LIB_DIR/helpers.sh"

# -----------------------------------------------------------------------------
# R Package Extraction
# -----------------------------------------------------------------------------

# Get list of R packages for an environment using rpixi list
# Usage: get_r_packages "environment-name"
get_r_packages() {
  local environment="$1"
  local packages=()
  local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local rpixi_path="${lib_dir}/../../rpixi.R"

  # Extract packages using rpixi list (relative path from lib directory)
  mapfile -t packages < <(Rscript "$rpixi_path" list -e "$environment" 2>/dev/null || true)

  if [[ ${#packages[@]} -eq 0 ]]; then
    debug "No R packages found for $environment"
    return 1
  fi

  printf '%s\n' "${packages[@]}"
  return 0
}

# -----------------------------------------------------------------------------
# R Package Loading Tests
# -----------------------------------------------------------------------------

# Test that a single R package can be loaded
# Usage: test_r_library "package_name"
test_r_library() {
  local package="$1"

  # Try to load the package
  if Rscript -e "suppressPackageStartupMessages(library('$package', quietly=TRUE))" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Test that all R packages can be loaded with library()
# Usage: test_r_libraries package1 package2 ...
test_r_libraries() {
  local packages=("$@")
  local failed_packages=()

  if [[ ${#packages[@]} -eq 0 ]]; then
    skip_test "No R packages to load"
    return 0
  fi

  TEST_TOTAL=$((TEST_TOTAL + ${#packages[@]}))

  # Convert bash array to R array string: c('pkg1', 'pkg2', ...)
  local r_packages_str
  r_packages_str=$(printf ", '%s'" "${packages[@]}")
  r_packages_str="c(${r_packages_str:2})"

  # Try to load all packages
  local result
  result=$(Rscript -e "
    options(warn = 2)
    failed <- character()

    loader <- function(x) {
      tryCatch({
        suppressPackageStartupMessages(library(x, character.only = TRUE, quietly = TRUE))
      }, error = function(e) {
        failed <<- c(failed, x)
      })
    }

    packages <- $r_packages_str
    invisible(lapply(packages, loader))

    if (length(failed) > 0) {
      cat(failed, sep = '\n')
      quit(status = 1)
    }
  " 2>&1)

  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    # Parse failed packages
    mapfile -t failed_packages <<<"$result"

    TEST_FAILED=$((TEST_FAILED + ${#failed_packages[@]}))
    TEST_PASSED=$((TEST_PASSED + ${#packages[@]} - ${#failed_packages[@]}))

    error "Failed to load ${#failed_packages[@]} R packages:"
    printf '    %s\n' "${failed_packages[@]}" >&2
    return 1
  else
    TEST_PASSED=$((TEST_PASSED + ${#packages[@]}))
    success "All ${#packages[@]} R packages loaded successfully"
    return 0
  fi
}

# Test R package loading in parallel
# Usage: test_r_libraries_parallel package1 package2 ...
test_r_libraries_parallel() {
  local packages=("$@")
  local failed_packages=()
  local pids=()
  local tempdir

  if [[ ${#packages[@]} -eq 0 ]]; then
    skip_test "No R packages to load"
    return 0
  fi

  TEST_TOTAL=$((TEST_TOTAL + ${#packages[@]}))

  # Create temp directory for results
  tempdir=$(make_temp_dir)

  # Test each package in parallel
  for i in "${!packages[@]}"; do
    (
      package="${packages[$i]}"
      if Rscript -e "suppressPackageStartupMessages(library('$package', quietly=TRUE))" 2>/dev/null; then
        echo "pass" >"$tempdir/$i"
      else
        echo "fail:$package" >"$tempdir/$i"
      fi
    ) &
    pids+=($!)
  done

  # Wait for all loads to complete
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done

  # Collect results
  for i in "${!packages[@]}"; do
    if [[ -f "$tempdir/$i" ]]; then
      result=$(cat "$tempdir/$i")
      if [[ "$result" == "pass" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
      else
        failed_packages+=("${packages[$i]}")
        TEST_FAILED=$((TEST_FAILED + 1))
      fi
    fi
  done

  # Cleanup
  rm -rf "$tempdir"

  # Report results
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    error "Failed to load ${#failed_packages[@]} R packages:"
    printf '    %s\n' "${failed_packages[@]}" >&2
    return 1
  else
    success "All ${#packages[@]} R packages loaded successfully"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Special Package Tests
# -----------------------------------------------------------------------------

# Test cmdstanr package (requires special CMDSTAN environment variable)
# Usage: test_cmdstanr
test_cmdstanr() {
  local packages=("$@")

  # Check if cmdstanr is in the package list
  local has_cmdstanr=0
  for pkg in "${packages[@]}"; do
    if [[ "$pkg" == "cmdstanr" ]]; then
      has_cmdstanr=1
      break
    fi
  done

  if [[ $has_cmdstanr -eq 0 ]]; then
    return 0
  fi

  # Set CMDSTAN path if not set
  if [[ -z "${CMDSTAN:-}" ]] && [[ -n "${CONDA_DIR:-}" ]]; then
    export CMDSTAN="${CONDA_DIR}/bin/cmdstan"
  fi

  # Test cmdstan_path()
  TEST_TOTAL=$((TEST_TOTAL + 1))
  if Rscript -e "options(warn=2); cmdstanr::cmdstan_path() |> invisible()" 2>/dev/null; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "cmdstanr is configured correctly"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "cmdstanr::cmdstan_path() failed"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Main Test Runner
# -----------------------------------------------------------------------------

# Run all R package tests for an environment
# Usage: test_r_packages "environment-name"
test_r_packages() {
  local environment="$1"
  local packages=()

  init_tests "R Packages ($environment)"

  # Check if rpixi.R is available (relative path from run-tests.sh location)
  local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local rpixi_path="${lib_dir}/../../rpixi.R"

  if [[ ! -f "$rpixi_path" ]]; then
    TEST_TOTAL=$((TEST_TOTAL + 1))
    TEST_FAILED=$((TEST_FAILED + 1))
    error "rpixi.R not found at $rpixi_path"
    print_test_summary
    return 1
  fi

  # Get R packages for this environment
  mapfile -t packages < <(get_r_packages "$environment")

  if [[ ${#packages[@]} -eq 0 ]]; then
    info "No R packages to test for $environment"
    return 0
  fi

  info "Found ${#packages[@]} R packages for $environment"
  if [[ "${TEST_DEBUG:-}" == "1" ]]; then
    debug "Packages:"
    printf '  %s\n' "${packages[@]}"
  fi

  # Run loading tests (parallel for speed)
  test_r_libraries_parallel "${packages[@]}" || true

  # Test special packages
  test_cmdstanr "${packages[@]}" || true

  # Print summary
  print_test_summary
}

# Export functions
export -f get_r_packages test_r_library test_r_libraries test_r_libraries_parallel
export -f test_cmdstanr test_r_packages
