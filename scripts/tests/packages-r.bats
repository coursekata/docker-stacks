#!/usr/bin/env bats

# One test per package from R_PACKAGES_FILE. bats parses `@test` blocks before
# any loop that would generate them runs, so registration goes through
# bats_test_function instead.

test_r_library() {
  local pkg="$1" out rc=0
  out=$(Rscript -e "suppressPackageStartupMessages(library('$pkg', quietly=TRUE))" 2>&1) || rc=$?
  if [[ $rc -ne 0 ]]; then
    # bats prints this on failure, so the R error reaches the log.
    printf '%s\n' "$out" | head -n 5
    return 1
  fi
}

# Unset, missing, and blank all mean "no packages"; only the diagnostic differs.
_resolve_r_packages() {
  if [[ -z "${R_PACKAGES_FILE:-}" ]]; then
    echo "R_PACKAGES_FILE is not set" >&2
    return 0
  fi
  if [[ ! -f "${R_PACKAGES_FILE}" ]]; then
    echo "R_PACKAGES_FILE (${R_PACKAGES_FILE}) does not exist" >&2
    return 0
  fi
  # Dedupe (order preserved): a name repeated across tier files would
  # otherwise register two identically-named bats_test_function calls, and
  # bats aborts the whole file load with "Duplicate test name(s)" rather
  # than just failing that one test.
  grep -v '^[[:space:]]*$' "${R_PACKAGES_FILE}" | awk '!seen[$0]++' || true
}

_no_r_packages_guard() {
  echo "no R packages resolved from R_PACKAGES_FILE=${R_PACKAGES_FILE:-<unset>}" >&2
  return 1
}

mapfile -t _R_PACKAGES < <(_resolve_r_packages)

if [[ ${#_R_PACKAGES[@]} -eq 0 ]]; then
  # Without this, an empty list registers zero tests and the run goes green.
  bats_test_function --description "R package list is non-empty" -- _no_r_packages_guard
else
  for _pkg in "${_R_PACKAGES[@]}"; do
    bats_test_function --description "library('$_pkg')" -- test_r_library "$_pkg"
  done
fi
