#!/usr/bin/env bats

# Jupyter server, kernel registration, and kernel execution.

get_available_kernels() {
  jupyter kernelspec list | tail -n +2 | awk '{print $1}'
}

# Requires both a clean exit and the computed value: exit status alone would
# pass a kernel that starts, answers nothing, and shuts down tidily.
run_kernel_probe() {
  local kernel="$1" code_file="$2" expected="$3"
  local output rc=0
  output=$(jupyter run --kernel "$kernel" "$code_file" 2>&1) || rc=$?
  if [[ $rc -ne 0 ]] || [[ "$output" != *"$expected"* ]]; then
    echo "kernel '$kernel' did not execute code (exit $rc, expected '$expected')"
    printf '%s\n' "$output"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Jupyter Installation
# -----------------------------------------------------------------------------
# The front end is absent on headless tiers like datascience-core, so each
# test self-skips; bats cannot skip a group as a unit.

@test "jupyter command is available" {
  command -v jupyter-lab >/dev/null 2>&1 || skip "Jupyter front end not installed on this tier"
  command -v jupyter
}

@test "jupyter --version works" {
  command -v jupyter-lab >/dev/null 2>&1 || skip "Jupyter front end not installed on this tier"
  jupyter --version
}

@test "jupyter notebook --version works" {
  command -v jupyter-lab >/dev/null 2>&1 || skip "Jupyter front end not installed on this tier"
  jupyter notebook --version
}

@test "jupyter lab --version works" {
  command -v jupyter-lab >/dev/null 2>&1 || skip "Jupyter front end not installed on this tier"
  jupyter lab --version
}

@test "Jupyter server config exists" {
  command -v jupyter-lab >/dev/null 2>&1 || skip "Jupyter front end not installed on this tier"
  [ -f "${HOME}/.jupyter/jupyter_server_config.py" ]
}

# -----------------------------------------------------------------------------
# Jupyter Kernels
# -----------------------------------------------------------------------------

@test "ir kernel is registered" {
  get_available_kernels | grep -qx "ir"
}

@test "python3 kernel is registered" {
  get_available_kernels | grep -qx "python3"
}

@test "DEFAULT_KERNEL is ir" {
  [ -n "${DEFAULT_KERNEL:-}" ] || skip "DEFAULT_KERNEL environment variable not set"
  [ "${DEFAULT_KERNEL}" = "ir" ]
}

@test "IRkernel package loads" {
  Rscript -e "library(IRkernel)"
}

# Parses the raw listing rather than the awk column, so a change to jupyter's
# indentation fails here and not silently.
@test "ir kernel appears in raw kernelspec listing" {
  jupyter kernelspec list | grep -q "^  ir "
}

@test "ir kernel.json exists under CONDA_DIR" {
  [ -n "${CONDA_DIR:-}" ] || skip "CONDA_DIR not set"
  [ -f "${CONDA_DIR}/share/jupyter/kernels/ir/kernel.json" ]
}

# -----------------------------------------------------------------------------
# Kernel Execution
# -----------------------------------------------------------------------------

@test "ir kernel executes code" {
  # jupyter run drops a connection file in JUPYTER_RUNTIME_DIR, which
  # defaults under a root-owned ~/.local in a bare container.
  export JUPYTER_RUNTIME_DIR="${BATS_TEST_TMPDIR}/runtime"
  local probe="${BATS_TEST_TMPDIR}/probe.R"
  # rlang is on every tier; loading it proves the kernel reaches the R library,
  # and the computed sentinel stops a kernel that only echoes input passing.
  printf 'library(rlang)\ncat(1 + 1, "ir-executed\\n")\n' >"$probe"
  run_kernel_probe ir "$probe" "2 ir-executed"
}

@test "python3 kernel executes code" {
  get_available_kernels | grep -qx "python3" || skip "python3 kernel not installed on this tier"
  export JUPYTER_RUNTIME_DIR="${BATS_TEST_TMPDIR}/runtime"
  local probe="${BATS_TEST_TMPDIR}/probe.py"
  printf 'print(1 + 1, "python-executed")\n' >"$probe"
  run_kernel_probe python3 "$probe" "2 python-executed"
}
