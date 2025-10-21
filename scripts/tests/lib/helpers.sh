#!/usr/bin/env bash

# helpers.sh - Common test utilities and helpers
# This library provides shared functionality for all test modules

set -euo pipefail

# -----------------------------------------------------------------------------
# Terminal Colors and Formatting
# -----------------------------------------------------------------------------

export COLOR_RESET='\033[0m'
export COLOR_BOLD='\033[1m'
export COLOR_DIM='\033[2m'
export COLOR_RED='\033[31m'
export COLOR_GREEN='\033[32m'
export COLOR_YELLOW='\033[33m'
export COLOR_BLUE='\033[34m'
export COLOR_MAGENTA='\033[35m'
export COLOR_CYAN='\033[36m'

# -----------------------------------------------------------------------------
# Logging and Output Functions
# -----------------------------------------------------------------------------

# Print a header in cyan with bold text
header() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_CYAN}==> $1${COLOR_RESET}"
}

# Print a subheader in cyan
subheader() {
  echo -e "${COLOR_CYAN}  • $1${COLOR_RESET}"
}

# Print a success message in green
success() {
  echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

# Print an error message in red
error() {
  echo -e "${COLOR_RED}✗ $1${COLOR_RESET}" >&2
}

# Print a warning message in yellow
warning() {
  echo -e "${COLOR_YELLOW}⚠ $1${COLOR_RESET}" >&2
}

# Print an info message in blue
info() {
  echo -e "${COLOR_BLUE}ℹ $1${COLOR_RESET}"
}

# Print a debug message in dim text (only if TEST_DEBUG is set)
debug() {
  if [[ "${TEST_DEBUG:-}" == "1" ]]; then
    echo -e "${COLOR_DIM}[DEBUG] $1${COLOR_RESET}" >&2
  fi
}

# -----------------------------------------------------------------------------
# Test State Management
# -----------------------------------------------------------------------------

# Global test counters (accumulate across all test sections)
export TEST_TOTAL=0
export TEST_PASSED=0
export TEST_FAILED=0
export TEST_SKIPPED=0

# Track test section
export TEST_SECTION=""

# Initialize test section (does NOT reset counters)
init_tests() {
  TEST_SECTION="$1"
  header "Testing: $TEST_SECTION"
}

# Print test summary (deprecated - use print_final_summary instead)
print_test_summary() {
  # No-op: individual summaries removed, use print_final_summary at end
  echo ""
}

# Print final summary for entire test run
print_final_summary() {
  local env_name="${1:-unknown}"

  echo ""
  echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"

  # Build summary line
  local summary="Total: ${TEST_TOTAL}, Passed: ${TEST_PASSED}, Failed: ${TEST_FAILED}"

  if [[ $TEST_SKIPPED -gt 0 ]]; then
    summary+=", Skipped: ${TEST_SKIPPED}"
  fi

  if [[ $TEST_FAILED -gt 0 ]]; then
    echo -e "${COLOR_RED}✗${COLOR_RESET} ${COLOR_BOLD}Test Results for ${env_name}${COLOR_RESET}"
    echo -e "$summary"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    return 1
  else
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Test Results for ${env_name}${COLOR_RESET}"
    echo -e "$summary"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Assertion Functions
# -----------------------------------------------------------------------------

# Assert that a command succeeds
# Usage: assert_success "description" command args...
assert_success() {
  local description="$1"
  shift

  TEST_TOTAL=$((TEST_TOTAL + 1))

  if "$@" >/dev/null 2>&1; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$description"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    # Flush stdout to ensure proper ordering with stderr
    exec 1>&1
    error "$description"
    debug "Failed command: $*"
    return 1
  fi
}

# Assert that a command fails
# Usage: assert_failure "description" command args...
assert_failure() {
  local description="$1"
  shift

  TEST_TOTAL=$((TEST_TOTAL + 1))

  if "$@" >/dev/null 2>&1; then
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$description (expected failure, but succeeded)"
    return 1
  else
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$description"
    return 0
  fi
}

# Assert that a file exists
# Usage: assert_file_exists "description" "/path/to/file"
assert_file_exists() {
  local description="$1"
  local file="$2"

  TEST_TOTAL=$((TEST_TOTAL + 1))

  if [[ -f "$file" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$description"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$description (file not found: $file)"
    return 1
  fi
}

# Assert that a directory exists
# Usage: assert_dir_exists "description" "/path/to/dir"
assert_dir_exists() {
  local description="$1"
  local dir="$2"

  TEST_TOTAL=$((TEST_TOTAL + 1))

  if [[ -d "$dir" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$description"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$description (directory not found: $dir)"
    return 1
  fi
}

# Assert that output contains a string
# Usage: echo "output" | assert_contains "description" "expected string"
assert_contains() {
  local description="$1"
  local expected="$2"
  local output

  output=$(cat)

  TEST_TOTAL=$((TEST_TOTAL + 1))

  if echo "$output" | grep -q "$expected"; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$description"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$description (expected: $expected)"
    debug "Actual output: $output"
    return 1
  fi
}

# Assert that two strings are equal
# Usage: assert_equals "description" "expected" "actual"
assert_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  TEST_TOTAL=$((TEST_TOTAL + 1))

  if [[ "$expected" == "$actual" ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "$description"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "$description"
    debug "Expected: $expected"
    debug "Actual:   $actual"
    return 1
  fi
}

# Skip a test with a reason
# Usage: skip_test "reason"
skip_test() {
  local reason="$1"

  TEST_TOTAL=$((TEST_TOTAL + 1))
  TEST_SKIPPED=$((TEST_SKIPPED + 1))

  warning "Skipped: $reason"
}

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Run a command and capture output
# Usage: output=$(run_command command args...)
run_command() {
  local output
  output=$("$@" 2>&1)
  echo "$output"
}

# Check if running inside a Docker container
is_docker() {
  [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null
}

# Get the test environment name from TEST_ENV or fall back to detecting from hostname
get_test_environment() {
  if [[ -n "${TEST_ENV:-}" ]]; then
    echo "$TEST_ENV"
  else
    # Try to detect from common patterns (you might need to customize this)
    echo "unknown"
  fi
}

# Check if a command is available
has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Require a command to be available, or skip test
require_command() {
  local cmd="$1"
  local reason="${2:-$cmd not available}"

  if ! has_command "$cmd"; then
    skip_test "$reason"
    return 1
  fi
  return 0
}

# Run tests in parallel and wait for all to complete
# Usage: run_parallel cmd1 cmd2 cmd3
run_parallel() {
  local pids=()

  # Start all commands in background
  for cmd in "$@"; do
    bash -c "$cmd" &
    pids+=($!)
  done

  # Wait for all and collect results
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  return $failed
}

# Measure execution time of a command
# Usage: time_command "description" command args...
time_command() {
  local description="$1"
  shift

  local start end duration
  start=$(date +%s%N)
  "$@"
  local result=$?
  end=$(date +%s%N)

  duration=$(((end - start) / 1000000)) # Convert to milliseconds

  if [[ $duration -gt 1000 ]]; then
    info "$description completed in $(awk "BEGIN {print $duration/1000}")s"
  else
    info "$description completed in ${duration}ms"
  fi

  return $result
}

# -----------------------------------------------------------------------------
# Test Setup and Teardown
# -----------------------------------------------------------------------------

# Register a cleanup function to run on exit
# Usage: on_exit cleanup_function
on_exit() {
  # shellcheck disable=SC2064
  trap "$*" EXIT
}

# Create a temporary directory for tests
make_temp_dir() {
  local dir
  dir=$(mktemp -d -t test.XXXXXX)
  echo "$dir"
}

# Print test suite header with dynamic box sizing
# Usage: print_header "environment-name"
print_header() {
  local env_name="$1"
  local title="CourseKata Docker Stacks - ${env_name} Test Suite"
  local width=$((${#title} + 4))

  echo ""
  printf "${COLOR_BOLD}${COLOR_CYAN}╔"
  printf '═%.0s' $(seq 1 $width)
  printf "╗${COLOR_RESET}\n"

  printf "${COLOR_BOLD}${COLOR_CYAN}║  %s  ║${COLOR_RESET}\n" "$title"

  printf "${COLOR_BOLD}${COLOR_CYAN}╚"
  printf '═%.0s' $(seq 1 $width)
  printf "╝${COLOR_RESET}\n"
  echo ""
}

# -----------------------------------------------------------------------------
# Export all functions
# -----------------------------------------------------------------------------

export -f header subheader success error warning info debug
export -f init_tests print_test_summary print_final_summary print_header
export -f assert_success assert_failure assert_file_exists assert_dir_exists
export -f assert_contains assert_equals skip_test
export -f run_command is_docker get_test_environment has_command require_command
export -f run_parallel time_command on_exit make_temp_dir
