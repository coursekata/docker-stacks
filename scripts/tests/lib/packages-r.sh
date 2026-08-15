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

# Get list of R packages for an environment using rpak list
# Usage: get_r_packages "environment-name"
get_r_packages() {
  local environment="$1"

  if [[ -z "${R_PACKAGES_FILE:-}" ]]; then
    error "R_PACKAGES_FILE is not set; the caller must provide the package list"
    return 1
  fi

  if [[ ! -f "${R_PACKAGES_FILE}" ]]; then
    error "R package list not found at ${R_PACKAGES_FILE}"
    return 1
  fi

  grep -v '^[[:space:]]*$' "${R_PACKAGES_FILE}"
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
      # Capture stderr to get error messages
      if error_msg=$(Rscript -e "suppressPackageStartupMessages(library('$package', quietly=TRUE))" 2>&1); then
        echo "pass" >"$tempdir/$i"
      else
        # Store both package name and error message
        echo "fail" >"$tempdir/$i"
        echo "$error_msg" >"$tempdir/$i.err"
      fi
    ) &
    pids+=($!)
  done

  # Wait for all loads to complete
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done

  # Collect results and error messages
  local -A error_messages
  for i in "${!packages[@]}"; do
    if [[ -f "$tempdir/$i" ]]; then
      result=$(cat "$tempdir/$i")
      if [[ "$result" == "pass" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
      else
        failed_packages+=("${packages[$i]}")
        TEST_FAILED=$((TEST_FAILED + 1))
        # Capture error message if available
        if [[ -f "$tempdir/$i.err" ]]; then
          error_messages["${packages[$i]}"]=$(cat "$tempdir/$i.err")
        fi
      fi
    fi
  done

  # Cleanup
  rm -rf "$tempdir"

  # Report results
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    error "Failed to load ${#failed_packages[@]} R packages:"
    for pkg in "${failed_packages[@]}"; do
      printf '    %s\n' "$pkg" >&2
      if [[ -n "${error_messages[$pkg]:-}" ]]; then
        # Indent error message and trim whitespace
        printf '        Error: %s\n' "${error_messages[$pkg]}" | sed 's/^/        /' | head -n 5 >&2
      fi
    done
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

  mapfile -t packages < <(get_r_packages "$environment")

  # An empty list means the list could not be read, not that the image has no R
  # packages. Returning success here lets the suite go green having asserted
  # nothing at all.
  if [[ ${#packages[@]} -eq 0 ]]; then
    TEST_TOTAL=$((TEST_TOTAL + 1))
    TEST_FAILED=$((TEST_FAILED + 1))
    error "No R packages resolved for $environment"
    print_test_summary
    return 1
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
