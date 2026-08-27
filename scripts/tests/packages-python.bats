#!/usr/bin/env bats

# Two tests per package from PYTHON_PACKAGES_FILE. bats parses `@test` blocks
# before any loop that would generate them runs, so registration goes through
# bats_test_function instead.

# A distribution's import name often differs from its package name.
get_import_name() {
  local package="$1"

  case "$package" in
  scikit-learn)
    echo "sklearn"
    return 0
    ;;
  esac

  python -c "
import sys
try:
    from importlib.metadata import distribution
    dist = distribution('$package')
    top_level = dist.read_text('top_level.txt')
    if top_level:
        print(top_level.strip().split()[0])
    else:
        print('$package'.replace('-', '_'))
except Exception:
    print('$package'.replace('-', '_'))
" 2>/dev/null
}

test_pip_show() {
  pip show "$1"
}

test_python_import() {
  local import_name
  import_name=$(get_import_name "$1")
  python -c "import $import_name"
}

# Unset, missing, and empty all mean "no packages"; only the diagnostic differs.
_resolve_python_packages() {
  if [[ -z "${PYTHON_PACKAGES_FILE:-}" ]]; then
    echo "PYTHON_PACKAGES_FILE is not set" >&2
    return 0
  fi
  if [[ ! -f "${PYTHON_PACKAGES_FILE}" ]]; then
    echo "PYTHON_PACKAGES_FILE (${PYTHON_PACKAGES_FILE}) does not exist" >&2
    return 0
  fi
  # Dedupe (order preserved): a name repeated across tier files would
  # otherwise register two identically-named bats_test_function calls, and
  # bats aborts the whole file load with "Duplicate test name(s)" rather
  # than just failing that one test.
  grep -v '^[[:space:]]*$' "${PYTHON_PACKAGES_FILE}" | awk '!seen[$0]++' || true
}

_no_python_packages_guard() {
  echo "no Python packages resolved from PYTHON_PACKAGES_FILE=${PYTHON_PACKAGES_FILE:-<unset>}" >&2
  return 1
}

mapfile -t _PYTHON_PACKAGES < <(_resolve_python_packages)

if [[ ${#_PYTHON_PACKAGES[@]} -eq 0 ]]; then
  # Without this, an empty list registers zero tests and the run goes green.
  bats_test_function --description "Python package list is non-empty" -- _no_python_packages_guard
else
  for _pkg in "${_PYTHON_PACKAGES[@]}"; do
    bats_test_function --description "pip show $_pkg" -- test_pip_show "$_pkg"
    bats_test_function --description "python -c 'import $_pkg'" -- test_python_import "$_pkg"
  done
fi
