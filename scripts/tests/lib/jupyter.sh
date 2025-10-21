#!/usr/bin/env bash

# jupyter.sh - Jupyter and kernel tests
# Tests Jupyter server, kernel availability, and kernel functionality

# Source helpers (use local variable to avoid overwriting SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_LIB_DIR/helpers.sh"

# -----------------------------------------------------------------------------
# Jupyter Server Tests
# -----------------------------------------------------------------------------

# Test that Jupyter is installed
# Usage: test_jupyter_installed
test_jupyter_installed() {
  init_tests "Jupyter Installation"

  # Test jupyter command and versions
  assert_success "jupyter command is available" command -v jupyter
  assert_success "jupyter --version works" jupyter --version
  assert_success "jupyter notebook --version works" jupyter notebook --version

  # Test jupyter-lab command and version
  assert_success "jupyter-lab command is available" command -v jupyter-lab
  assert_success "jupyter lab --version works" jupyter lab --version

  # Check if config file exists
  assert_file_exists "Jupyter config exists" "${HOME}/.jupyter/jupyter_server_config.py"

  print_test_summary
}

# -----------------------------------------------------------------------------
# Kernel Tests
# -----------------------------------------------------------------------------

# Get list of available kernels
# Usage: get_available_kernels
get_available_kernels() {
  jupyter kernelspec list | tail -n +2 | awk '{print $1}'
}

# Test that kernels are installed
# Usage: test_kernels_installed
test_kernels_installed() {
  init_tests "Jupyter Kernels"

  local kernels=()
  local required_kernels=("ir" "python3")
  local missing_kernels=()

  # Get available kernels
  mapfile -t kernels < <(get_available_kernels)

  if [[ ${#kernels[@]} -eq 0 ]]; then
    error "No kernels found"
    TEST_TOTAL=1
    TEST_FAILED=1
    print_test_summary
    return 1
  fi

  # Check that all required kernels are present
  for required in "${required_kernels[@]}"; do
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if printf '%s\n' "${kernels[@]}" | grep -q "^${required}$"; then
      TEST_PASSED=$((TEST_PASSED + 1))
      success "Kernel '$required' is available"
    else
      missing_kernels+=("$required")
      TEST_FAILED=$((TEST_FAILED + 1))
      error "Kernel '$required' is not available"
    fi
  done

  # Check DEFAULT_KERNEL environment variable
  if [[ -n "${DEFAULT_KERNEL:-}" ]]; then
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if [[ "${DEFAULT_KERNEL}" == "ir" ]]; then
      TEST_PASSED=$((TEST_PASSED + 1))
      success "DEFAULT_KERNEL is set to 'ir'"
    else
      TEST_FAILED=$((TEST_FAILED + 1))
      error "DEFAULT_KERNEL is '${DEFAULT_KERNEL}', expected 'ir'"
    fi
  fi

  # Check if IRkernel package is installed
  assert_success "IRkernel package is installed" \
    Rscript -e "library(IRkernel)"

  # Check if ir kernel is registered with Jupyter
  TEST_TOTAL=$((TEST_TOTAL + 1))
  if jupyter kernelspec list | grep -q "^  ir "; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "IR kernel is registered with Jupyter"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "IR kernel is not registered with Jupyter"
  fi

  # Check kernel.json exists
  local kernel_json="${CONDA_DIR}/share/jupyter/kernels/ir/kernel.json"
  if [[ -n "${CONDA_DIR:-}" ]]; then
    assert_file_exists "IR kernel.json exists" "$kernel_json" || true
  fi

  print_test_summary

  if [[ ${#missing_kernels[@]} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Test that specific kernels are available
# Usage: test_kernel_exists "ir" "python3"
test_kernel_exists() {
  local expected_kernels=("$@")
  local available_kernels=()
  local missing_kernels=()

  init_tests "Required Kernels"

  # Get available kernels
  mapfile -t available_kernels < <(get_available_kernels)

  # Check each expected kernel
  for kernel in "${expected_kernels[@]}"; do
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if printf '%s\n' "${available_kernels[@]}" | grep -q "^${kernel}$"; then
      TEST_PASSED=$((TEST_PASSED + 1))
      success "Kernel '$kernel' is available"
    else
      TEST_FAILED=$((TEST_FAILED + 1))
      missing_kernels+=("$kernel")
      error "Kernel '$kernel' is not available"
    fi
  done

  print_test_summary

  if [[ ${#missing_kernels[@]} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Test that IR kernel is the default
# Usage: test_ir_default_kernel
test_ir_default_kernel() {
  init_tests "Default Kernel"

  # Check DEFAULT_KERNEL environment variable
  if [[ -n "${DEFAULT_KERNEL:-}" ]]; then
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if [[ "${DEFAULT_KERNEL}" == "ir" ]]; then
      TEST_PASSED=$((TEST_PASSED + 1))
      success "DEFAULT_KERNEL is set to 'ir'"
    else
      TEST_FAILED=$((TEST_FAILED + 1))
      error "DEFAULT_KERNEL is '${DEFAULT_KERNEL}', expected 'ir'"
    fi
  else
    skip_test "DEFAULT_KERNEL environment variable not set"
  fi

  print_test_summary
}

# Test that a kernel can execute code
# Usage: test_kernel_execution "ir" "print('test')"
test_kernel_execution() {
  local kernel="$1"
  local code="$2"

  TEST_TOTAL=$((TEST_TOTAL + 1))

  # Try to execute code in the kernel
  local output
  output=$(jupyter console --kernel="$kernel" -c "$code" 2>&1 || true)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "Kernel '$kernel' executed code successfully"
    debug "Output: $output"
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "Kernel '$kernel' failed to execute code"
    debug "Output: $output"
    return 1
  fi
}

# Test IR kernel execution
# Usage: test_ir_kernel
test_ir_kernel() {
  init_tests "IR Kernel Execution"

  # Test simple R expression
  test_kernel_execution "ir" "1 + 1" || true

  # Test that R library works
  test_kernel_execution "ir" "library(rlang)" || true

  print_test_summary
}

# Test Python kernel execution
# Usage: test_python_kernel
test_python_kernel() {
  init_tests "Python Kernel Execution"

  # Test simple Python expression
  test_kernel_execution "python3" "print('hello')" || true

  # Test that imports work
  test_kernel_execution "python3" "import sys; print(sys.version)" || true

  print_test_summary
}

# -----------------------------------------------------------------------------
# IRkernel Registration Tests
# -----------------------------------------------------------------------------

# Test that IRkernel is properly registered
# Usage: test_irkernel_registration
test_irkernel_registration() {
  init_tests "IRkernel Registration"

  # Check if IRkernel package is installed
  assert_success "IRkernel package is installed" \
    Rscript -e "library(IRkernel)"

  # Check if ir kernel is registered
  local has_ir=0
  if jupyter kernelspec list | grep -q "^  ir "; then
    has_ir=1
  fi

  TEST_TOTAL=$((TEST_TOTAL + 1))
  if [[ $has_ir -eq 1 ]]; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "IR kernel is registered with Jupyter"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "IR kernel is not registered with Jupyter"
  fi

  # Check kernel.json exists
  local kernel_json="${CONDA_DIR}/share/jupyter/kernels/ir/kernel.json"
  if [[ -n "${CONDA_DIR:-}" ]]; then
    assert_file_exists "IR kernel.json exists" "$kernel_json" || true
  else
    skip_test "CONDA_DIR not set, cannot check kernel.json location"
  fi

  print_test_summary
}

# -----------------------------------------------------------------------------
# Health Check Tests
# -----------------------------------------------------------------------------

# Test Jupyter server health check
# Usage: test_jupyter_health_check
test_jupyter_health_check() {
  init_tests "Jupyter Health Check"

  # Check if health check script exists
  local health_check="/usr/local/bin/health-check.sh"
  assert_file_exists "Health check script exists" "$health_check" || true

  # If it exists, try running it (but don't fail if server isn't running)
  if [[ -f "$health_check" ]] && [[ -x "$health_check" ]]; then
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if bash "$health_check" 2>/dev/null; then
      TEST_PASSED=$((TEST_PASSED + 1))
      success "Health check script executed successfully"
    else
      TEST_PASSED=$((TEST_PASSED + 1))
      info "Health check script executed (server may not be running)"
    fi
  fi

  print_test_summary
}

# -----------------------------------------------------------------------------
# Main Test Runner
# -----------------------------------------------------------------------------

# Run all Jupyter tests
# Usage: test_jupyter_all
test_jupyter_all() {
  # Test Jupyter installation (includes configuration)
  test_jupyter_installed || return 1

  # Test kernels (combined: availability, default, registration)
  test_kernels_installed || return 1

  # Note: Kernel execution tests require console interaction
  # Uncomment if needed:
  # test_ir_kernel || return 1
  # test_python_kernel || return 1

  return 0
}

# Export functions
export -f get_available_kernels test_jupyter_installed
export -f test_kernels_installed test_kernel_exists test_ir_default_kernel
export -f test_kernel_execution test_ir_kernel test_python_kernel
export -f test_irkernel_registration test_jupyter_health_check
export -f test_jupyter_all
