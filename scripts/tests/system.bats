#!/usr/bin/env bats

# System environment tests: user setup, permissions, activation, R/Python
# toolchain. One @test per assertion; bats reports each independently
# instead of folding them into a shared pass/fail counter.

# -----------------------------------------------------------------------------
# User Setup
# -----------------------------------------------------------------------------

@test "current user is jovyan" {
  [ "$(whoami)" = "jovyan" ]
}

@test "home directory exists" {
  [ -d "$HOME" ]
}

@test "work directory exists" {
  [ -d "${HOME}/work" ]
}

@test "home directory is writable" {
  local probe="${HOME}/.permission_test"
  touch "$probe" && rm "$probe"
}

@test "work directory is writable" {
  local probe="${HOME}/work/.permission_test"
  touch "$probe" && rm "$probe"
}

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------

@test "HOME is set and exists" {
  [ -n "${HOME:-}" ]
  [ -d "$HOME" ]
}

@test "CONDA_DIR is set and exists" {
  [ -n "${CONDA_DIR:-}" ]
  [ -d "$CONDA_DIR" ]
}

@test "CONDA_DEFAULT_ENV is set" {
  [ -n "${CONDA_DEFAULT_ENV:-}" ]
}

# -----------------------------------------------------------------------------
# Python Environment
# -----------------------------------------------------------------------------

@test "python3 command is available" {
  command -v python3
}

@test "python command is available" {
  command -v python
}

@test "pip command is available" {
  command -v pip
}

# -----------------------------------------------------------------------------
# R Environment
# -----------------------------------------------------------------------------

@test "R command is available" {
  command -v R
}

@test "R --version works" {
  R --version
}

@test "Rscript command is available" {
  command -v Rscript
}

@test "Rscript --version works" {
  Rscript --version
}

@test "R_HOME is set and exists" {
  [ -d "${R_HOME:-/notset}" ]
}

@test "Rprofile.site exists" {
  [ -f "${R_HOME:-}/etc/Rprofile.site" ]
}

@test "PPM repository is configured with correct codename" {
  local ppm_repo ubuntu_codename
  ppm_repo=$(Rscript -e "cat(getOption('repos')[['CRAN']])")
  [ -n "$ppm_repo" ]
  ubuntu_codename=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
  echo "$ppm_repo" | grep -q "__linux__/${ubuntu_codename}/"
}

@test "pak resolves against a single rolling repo" {
  # Ask pak what it resolved against, not getOption('repos'): pkgcache
  # injects its own rolling CRAN/Bioconductor repos that never show up there.
  local repos_count repos_names ppm_repo
  repos_count=$(Rscript -e "cat(nrow(pak::repo_get()))")
  repos_names=$(Rscript -e "cat(unique(pak::repo_get()\$name))")
  ppm_repo=$(Rscript -e "cat(getOption('repos')[['CRAN']])")
  [ "$repos_count" = "1" ]
  [ "$repos_names" = "CRAN" ]
  echo "$ppm_repo" | grep -qE '__linux__/[^/]+/latest$'
}

@test "R can generate plots" {
  Rscript -e "png(tempfile()); plot(1:10); dev.off()"
}
