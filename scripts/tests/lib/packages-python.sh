#!/usr/bin/env bash

# packages-python.sh - Python package installation and import tests
# Tests that all Python packages can be imported without errors

# Source helpers (use local variable to avoid overwriting SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$_LIB_DIR/helpers.sh"

# -----------------------------------------------------------------------------
# Python Package Extraction
# -----------------------------------------------------------------------------

# Get list of Python packages for an environment
# Prefers pre-generated package list from host, falls back to generating it
# Usage: get_python_packages "environment-name"
get_python_packages() {
  local environment="$1"
  local packages=()

  # Check if package list was pre-generated on host (preferred method)
  if [[ -n "${PYTHON_PACKAGES_FILE:-}" ]] && [[ -f "${PYTHON_PACKAGES_FILE}" ]]; then
    mapfile -t packages < "${PYTHON_PACKAGES_FILE}"
  # Fall back to generating it (for local development/debugging)
  elif [[ -f "${HOME}/scripts/list-python-packages.sh" ]]; then
    mapfile -t packages < <("${HOME}/scripts/list-python-packages.sh" "$environment" 2>/dev/null || true)
  else
    debug "No Python package source available"
    return 1
  fi

  # Filter out empty strings from the array
  local filtered_packages=()
  for pkg in "${packages[@]}"; do
    [[ -n "$pkg" ]] && filtered_packages+=("$pkg")
  done

  if [[ ${#filtered_packages[@]} -eq 0 ]]; then
    debug "No Python packages found for $environment"
    return 1
  fi

  printf '%s\n' "${filtered_packages[@]}"
  return 0
}

# Get the actual import name for a package using its metadata
# Usage: get_import_name "package-name"
get_import_name() {
  local package="$1"

  # Handle known packages with non-standard import names
  # These packages lack proper top_level.txt metadata
  case "$package" in
  beautifulsoup4)
    echo "bs4"
    return 0
    ;;
  scikit-learn)
    echo "sklearn"
    return 0
    ;;
  esac

  # Try to get import name from package metadata
  python -c "
import sys
try:
    from importlib.metadata import distribution
    dist = distribution('$package')
    # Get top-level modules from metadata
    top_level = dist.read_text('top_level.txt')
    if top_level:
        # Return first top-level module
        print(top_level.strip().split()[0])
    else:
        # Fallback: convert hyphens to underscores
        print('$package'.replace('-', '_'))
except Exception:
    # Fallback for packages without metadata
    print('$package'.replace('-', '_'))
" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Python Package Installation Tests
# -----------------------------------------------------------------------------

# Test that Python packages are installed (using pip show)
# Usage: test_python_packages_installed package1 package2 ...
test_python_packages_installed() {
  local packages=("$@")

  if [[ ${#packages[@]} -eq 0 ]]; then
    skip_test "No Python packages to test"
    return 0
  fi

  # Use pip show to check all packages at once
  local output
  output=$(pip show "${packages[@]}" 2>&1 || true)

  # Check for packages not found
  local warning_prefix="WARNING: Package(s) not found"
  if echo "$output" | grep -q "$warning_prefix"; then
    error "Some Python packages are not installed:"
    # Show the complete warning message(s)
    echo "$output" | grep "$warning_prefix" | sed 's/^/    /' >&2
    TEST_TOTAL=$((TEST_TOTAL + ${#packages[@]}))
    TEST_FAILED=$((TEST_FAILED + ${#packages[@]}))
    return 1
  else
    TEST_TOTAL=$((TEST_TOTAL + ${#packages[@]}))
    TEST_PASSED=$((TEST_PASSED + ${#packages[@]}))
    success "All ${#packages[@]} Python packages are installed"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Python Package Import Tests
# -----------------------------------------------------------------------------

# Test that a single Python package can be imported
# Usage: test_python_import "package_name"
test_python_import() {
  local package="$1"
  local import_name

  # Get the actual import name from package metadata
  import_name=$(get_import_name "$package")

  # Try to import the package
  if python -c "import $import_name" 2>/dev/null; then
    TEST_PASSED=$((TEST_PASSED + 1))
    return 0
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    return 1
  fi
}

# Test that all Python packages can be imported
# Usage: test_python_imports package1 package2 ...
test_python_imports() {
  local packages=("$@")
  local failed_packages=()
  local i

  if [[ ${#packages[@]} -eq 0 ]]; then
    skip_test "No Python packages to import"
    return 0
  fi

  subheader "Testing ${#packages[@]} Python packages can be imported"

  TEST_TOTAL=$((TEST_TOTAL + ${#packages[@]}))

  # Test each package import
  for package in "${packages[@]}"; do
    import_name=$(get_import_name "$package")
    if ! python -c "import $import_name" 2>/dev/null; then
      failed_packages+=("$package")
      TEST_FAILED=$((TEST_FAILED + 1))
    else
      TEST_PASSED=$((TEST_PASSED + 1))
    fi
  done

  # Report results
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    error "Failed to import ${#failed_packages[@]} Python packages:"
    printf '    %s\n' "${failed_packages[@]}" >&2
    return 1
  else
    success "All ${#packages[@]} Python packages imported successfully"
    return 0
  fi
}

# Test imports in parallel for speed
# Usage: test_python_imports_parallel package1 package2 ...
test_python_imports_parallel() {
  local packages=("$@")
  local failed_packages=()
  local pids=()
  local tempdir

  if [[ ${#packages[@]} -eq 0 ]]; then
    skip_test "No Python packages to import"
    return 0
  fi

  TEST_TOTAL=$((TEST_TOTAL + ${#packages[@]}))

  # Create temp directory for results
  tempdir=$(make_temp_dir)

  # Test each package import in parallel
  for i in "${!packages[@]}"; do
    (
      package="${packages[$i]}"
      import_name=$(get_import_name "$package")
      if python -c "import $import_name" 2>/dev/null; then
        echo "pass" >"$tempdir/$i"
      else
        echo "fail:$package" >"$tempdir/$i"
      fi
    ) &
    pids+=($!)
  done

  # Wait for all imports to complete
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
    error "Failed to import ${#failed_packages[@]} Python packages:"
    printf '    %s\n' "${failed_packages[@]}" >&2
    return 1
  else
    success "All ${#packages[@]} Python packages imported successfully"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Main Test Runner
# -----------------------------------------------------------------------------

# Run all Python package tests for an environment
# Usage: test_python_packages "environment-name"
test_python_packages() {
  local environment="$1"
  local packages=()

  init_tests "Python Packages ($environment)"

  # Get Python packages for this environment
  mapfile -t packages < <(get_python_packages "$environment")

  if [[ ${#packages[@]} -eq 0 ]]; then
    info "No Python packages to test for $environment"
    return 0
  fi

  info "Found ${#packages[@]} Python packages for $environment"
  if [[ "${TEST_DEBUG:-}" == "1" ]]; then
    debug "Packages:"
    printf '  %s\n' "${packages[@]}"
  fi

  # Run installation tests
  test_python_packages_installed "${packages[@]}" || true

  # Run import tests (parallel for speed)
  test_python_imports_parallel "${packages[@]}" || true

  # Print summary
  print_test_summary
}

# Export functions
export -f get_python_packages get_import_name test_python_packages_installed
export -f test_python_import test_python_imports test_python_imports_parallel
export -f test_python_packages
