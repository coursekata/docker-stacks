#!/usr/bin/env bash

# system.sh - System environment and configuration tests
# Tests user setup, permissions, environment activation, and runtime configuration

# Source helpers (use local variable to avoid overwriting SCRIPT_DIR)
# shellcheck source=tests/lib/helpers.sh
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/helpers.sh"

# -----------------------------------------------------------------------------
# User and Permissions
# -----------------------------------------------------------------------------

# Test user setup
test_user_setup() {
  init_tests "User Setup"

  # Check current user
  local current_user
  current_user=$(whoami)
  assert_equals "User is jovyan" "jovyan" "$current_user"

  # Check UID
  local current_uid
  current_uid=$(id -u)
  info "Current UID: $current_uid"

  # Check home directory
  assert_dir_exists "Home directory exists" "$HOME"
  assert_dir_exists "Work directory exists" "${HOME}/work"

  # Test that user can write to home
  TEST_TOTAL=$((TEST_TOTAL + 1))
  local test_file="${HOME}/.permission_test"
  if touch "$test_file" 2>/dev/null && rm "$test_file" 2>/dev/null; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "Can write to home directory"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "Cannot write to home directory"
  fi

  # Test that user can write to work directory
  TEST_TOTAL=$((TEST_TOTAL + 1))
  test_file="${HOME}/work/.permission_test"
  if touch "$test_file" 2>/dev/null && rm "$test_file" 2>/dev/null; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "Can write to work directory"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "Cannot write to work directory"
  fi

  print_test_summary
}

# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------

# Test R environment setup
test_r_environment() {
  init_tests "R Environment"

  # Check R is available and get version
  assert_success "R command is available" command -v R
  assert_success "R --version works" R --version

  # Check Rscript is available and get version
  assert_success "Rscript command is available" command -v Rscript
  assert_success "Rscript --version works" Rscript --version

  # Check R installation paths
  assert_dir_exists "R_HOME is set and exists" "${R_HOME:-/notset}"
  assert_file_exists "Rprofile.site exists" "${R_HOME}/etc/Rprofile.site"

  # Test that PPM is configured with correct Ubuntu codename
  TEST_TOTAL=$((TEST_TOTAL + 1))
  local ppm_repo
  ppm_repo=$(Rscript -e "cat(getOption('repos')[['PPM']])")
  if [[ -n "$ppm_repo" ]]; then
    # Extract Ubuntu codename from system
    local ubuntu_codename
    ubuntu_codename=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)

    # Check if PPM URL contains the correct codename
    if echo "$ppm_repo" | grep -q "__linux__/${ubuntu_codename}/"; then
      TEST_PASSED=$((TEST_PASSED + 1))
      success "PPM repository is configured with correct codename: $ppm_repo"
    else
      TEST_FAILED=$((TEST_FAILED + 1))
      error "PPM repository codename mismatch. Expected '${ubuntu_codename}' in: $ppm_repo"
    fi
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "PPM repository not configured"
  fi

  # Test that CRAN is configured
  TEST_TOTAL=$((TEST_TOTAL + 1))
  local cran_repo
  cran_repo=$(Rscript -e "cat(getOption('repos')[['CRAN']])")
  if [[ -n "$cran_repo" ]] && [[ "$cran_repo" != "@CRAN@" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "CRAN repository is configured: $cran_repo"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "CRAN repository not configured"
  fi

  # Test that PPM is prioritized over CRAN in repository order
  TEST_TOTAL=$((TEST_TOTAL + 1))
  local ppm_index cran_index
  ppm_index=$(Rscript -e "cat(which(names(getOption('repos')) == 'PPM'))")
  cran_index=$(Rscript -e "cat(which(names(getOption('repos')) == 'CRAN'))")
  if [[ -n "$ppm_index" ]] && [[ -n "$cran_index" ]] && [[ "$ppm_index" -lt "$cran_index" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "PPM is prioritized over CRAN (PPM at position $ppm_index, CRAN at position $cran_index)"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "PPM is not prioritized over CRAN in repository order"
  fi

  # Test R can create plots
  assert_success "R can generate plots" \
    Rscript -e "png(tempfile()); plot(1:10); dev.off()"

  print_test_summary
}

# Test Python environment setup
test_python_environment() {
  init_tests "Python Environment"

  assert_success "python3 command is available" command -v python3
  assert_success "python command is available" command -v python
  assert_success "pip command is available" command -v pip

  print_test_summary
}

# Test environment variables
test_environment_variables() {
  init_tests "Environment Variables"

  # Check required environment variables are set and directories exist
  assert_env_var_set_and_exists "HOME" "$HOME"
  assert_env_var_set_and_exists "CONDA_DIR" "${CONDA_DIR:-}"
  assert_env_var_set_and_exists "R_HOME" "${R_HOME:-}"

  # Check conda environment
  TEST_TOTAL=$((TEST_TOTAL + 1))
  if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "CONDA_DEFAULT_ENV is set to: $CONDA_DEFAULT_ENV"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    warning "CONDA_DEFAULT_ENV not set"
  fi

  print_test_summary
}

# Helper to check environment variable is set and path exists
assert_env_var_set_and_exists() {
  local var_name="$1"
  local var_value="$2"

  TEST_TOTAL=$((TEST_TOTAL + 1))
  if [[ -n "$var_value" ]] && [[ -d "$var_value" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$var_name is set and exists: $var_value"
  elif [[ -n "$var_value" ]]; then
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$var_name is set but directory does not exist: $var_value"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$var_name is not set"
  fi
}

# -----------------------------------------------------------------------------
# Export all functions
# -----------------------------------------------------------------------------

export -f test_user_setup
export -f test_r_environment test_python_environment
export -f test_environment_variables
