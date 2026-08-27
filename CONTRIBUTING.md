# Contributing to CourseKata Docker Stacks

This guide covers development workflows, testing, CI/CD, and contribution guidelines.

## Development Workflow

### Prerequisites

- Docker Desktop or Docker Engine
- GitHub CLI (`gh`) or `GITHUB_TOKEN` environment variable
- [just](https://github.com/casey/just) command runner
- Pixi (optional, for local dependency management)
- [prek](https://github.com/anthropics/prek) for pre-commit hooks

### Setting Up Pre-commit Hooks

This project uses pre-commit hooks to run local checks. Install prek and set up the hooks:

```bash
# Install prek (requires pipx or pip)
pipx install prek

# Install the pre-commit hooks
prek install
```

### Building Images Locally

Use `just` recipes to build images:

```bash
# Build for your current architecture
just build r-notebook

# Build for a specific architecture
just build r-notebook amd64
just build datascience-notebook arm64

# Build all images
just build-all
just build-all amd64
```

The build system automatically pulls cache from `ghcr.io/coursekata/*` if `DS_OWNER` is set.

### Testing Images

Always test after building:

```bash
# Test after building
just test r-notebook
just test essentials-notebook amd64

# Test all images
just test-all
```

See [Testing](#testing) for how the suite is structured.

### Running Containers

```bash
# Run container and get shell access
just shell r-notebook

# Run container normally (starts Jupyter)
just run datascience-notebook
```

### Direct Script Usage

`just` wraps `scripts/build-image.sh`, which takes more than the recipes expose:

```bash
./scripts/build-image.sh --image r-notebook --platform linux/amd64 --tag my-tag
./scripts/build-image.sh --image r-notebook --platform linux/amd64 --target test
```

Testing, shelling in, and running Jupyter are `docker run` against a built tag,
so they stay in the justfile rather than in scripts of their own.

## Testing

### Test Architecture

Tests run inside the image they are testing, against the Dockerfile's `test`
stage: `final` plus bats, the suite, and the package lists the suite asserts
against. Nothing is mounted at run time and nothing is resolved on the host, so
`docker run <test image>` is the whole invocation and CI exercises the same
image a developer does.

Tests run in a fixed order: fast environment checks first, slow package
validation last.

### Test Execution Flow

`just test <image>` builds `--target test` and runs it. Building the test stage
builds the image under test, so there is no separate build step to keep in sync.

CI does the same in two steps: it pushes `final` by digest, then builds `test`
on top of the cache it just wrote, so the tested layers are the pushed ones.

### What Gets Tested

Each image is tested for:

1. **System Configuration**:
   - User setup (jovyan user, permissions)
   - Environment variables (CONDA_DIR, R_HOME, etc.)
   - Python environment (python3, pip3, versions)
   - R environment (R version, CRAN/PPM repos, Rprofile)

2. **Jupyter Setup**:
   - Jupyter server installation and versions
   - Kernel availability (IR, Python3)
   - IRkernel registration
   - Default kernel configuration
   - Kernel execution (one cell through `ir` and `python3`)

3. **Package Installation**:
   - Python packages: installation check (`pip show`) and import validation
   - R packages: loading via `library()` and special configurations (cmdstanr)

### Adding Tests

Tests are [bats-core](https://bats-core.readthedocs.io/) files under `scripts/tests/`. `run-tests.sh` hands bats the whole directory, so a new `.bats` file runs without being wired in anywhere.

`packages-python.bats` and `packages-r.bats` generate one test per package from
`PYTHON_PACKAGES_FILE` and `R_PACKAGES_FILE`. The test stage resolves both with
`scripts/get-refs.py` and bakes them in, so they are already set inside the
image; running a file standalone elsewhere needs them set by hand.

Execution is serial: bats `--jobs` needs GNU parallel, which the images do not carry. `TEST_DEBUG=1` adds `--trace --show-output-of-passing-tests`.

bats itself is not in the published images. It is installed by the Dockerfile's `test` stage, which is built with `--target test` and never published — the `images` job targets `final` explicitly and the static gate asserts no published target installs it.

## CI/CD

### GitHub Actions Workflow

The CI/CD pipeline is defined in `.github/workflows/`:

- **`build-test-push.yml`**: Main workflow that builds, tests, and pushes a single image
- **`build-test-push-multiarch.yml`**: Orchestrates builds for both ARM64 and AMD64 architectures

### Workflow Steps

For each image and platform:

1. **Update dependencies**: `pixi update` to get latest package versions
2. **Build image**: Docker Buildx with registry caching
3. **Test image**: Executes the same test suite that runs locally
4. **Push by digest**: Pushes image by digest to enable multi-arch manifests
5. **Create manifest**: Combines AMD64 and ARM64 images into multi-arch manifest

### Caching Strategy

The build system uses Docker registry caching:

- **Cache source**: `:latest` and `:cache-{amd64,arm64}` tags from registry
- **Cache target**: Platform-specific cache tags (`:cache-amd64`, `:cache-arm64`)
- **Local builds**: Automatically pull cache from `ghcr.io/coursekata/*` if `DS_OWNER` is set

This dramatically speeds up builds by reusing layers from previous builds.

### Common CI/CD Issues

#### `texlive` Installation Hangs

The `base` stage installs `texlive`, which can hang on GitHub Actions `ubuntu-latest` runners.

**Solution**: Run `just test base-r-notebook` locally to cache the base layer to the registry. This allows GitHub Actions to skip building the base stage and use the cached layer.

#### Test Failures

If tests fail in CI:

1. Pull the image locally: `docker pull ghcr.io/coursekata/<image>:cache-<platform>`
2. Run tests locally: `just test <image>`
3. Debug with `TEST_DEBUG=1` environment variable
4. Run a single file: `bats scripts/tests/<file>.bats` inside the test image

## Modifying Dependencies

### Conda Packages (Python, R base, system packages)

1. Run `pixi add --feature <feature-name> <package-name>` to add the package and update the lock file
   - Note you can also scope it to a platform with `--platform linux-amd64` or `--platform linux-aarch64`
2. Rebuild and test: `just build <image> && just test <image>`

### R Packages

1. Edit the relevant `r/<feature>.txt` file — one pak ref per line, `#` comments
   and blank lines allowed. The filename is the feature name.
2. Do **not** add a matching `r-*` package via `pixi add`. conda-forge has no `r-*`
   builds for R 4.6, so a single one pins the whole solve-group back to 4.5.x and
   silently downgrades R for every image.
3. Rebuild and test: `just build <image> && just test <image>`

A bare name means CRAN. An off-CRAN package needs a pak ref pinned to a full
40-hex commit SHA — `<package>=<owner>/<repo>@<sha>` — never a tag or branch,
both of which can move out from under a resolved build. Append `?reinstall`
to force a reinstall even when pak thinks the version is already satisfied.

Example:

```txt
coursekata=coursekata/coursekata-r@5e68e7716b02065823d17491de4a18e57774185e?reinstall
ggpubr
```

`just gate static` validates the ref syntax; nothing needs regenerating.

## The Six Images

One `Dockerfile` builds all six images; a `PIXI_ENV` build arg selects
which Pixi environment gets installed into it. The images are **not**
`FROM`-chained — nothing is built on top of anything else here.
"Downstream" describes cumulative *manifest features* (a package present
in `r-notebook` and everything above it), not an inherited image layer.
Containment is proven statically, from the committed `pixi.lock`, before
any image is built — that's what `just gate static` does — not by
rebuilding and diffing, and not by inheritance. `pixi.toml`'s
`[environments.*]` `features` lists are the single definition of tier
composition for both languages: the R side parses `pixi.toml` directly
(`scripts/get-refs.py`) and concatenates the matching `r/<feature>.txt`
files, including the two instructor features, which carry no conda
packages at all.

Four tiers form a ladder, each a superset of the one before:

1. **`base-r-notebook`** — R and Jupyter, and that's it.
2. **`essentials-notebook`** — + the `coursekata` teaching stack: everything
   used in the CourseKata books.
3. **`r-notebook`** — + the modelling/tidyverse stack: extended R packages
   instructors have asked for.
4. **`datascience-notebook`** — + Bayesian modelling, machine learning, and
   further instructor-requested Python and R packages.

Two more images exist for specific consumers and sit outside the ladder:

- **`datascience-core`** — everything in `datascience-notebook` except the
  Jupyter front end (`jupyterlab`, `notebook`, `nbclassic`,
  `jupyterhub-singleuser`). For a consumer that brings its own notebook
  server — CKHub, which is pinned to classic Notebook 6 and would otherwise
  inherit an unused JupyterLab install it has to overwrite. Nothing in this
  repository builds on it; it's a fifth environment in the same Pixi
  solve group as the ladder, so it stays version-identical with
  `datascience-notebook` on every package they share.
- **`exercises-notebook`** — `essentials-notebook` + the exercise-checking
  machinery (`pythonwhat`, `testwhat`) that grades the book's inline
  exercises. A **leaf**: nothing is built on top of it. It lives in its
  **own Pixi solve group**, separate from the ladder, because `pythonwhat`
  declares a hard `asttokens<3` ceiling that only it needs — inside a
  shared solve group that ceiling would reach every tier, including
  `base-r-notebook`, which contains no Python teaching stack at all.

**Important**: a change to a feature multiple environments share — anything
in `pixi.toml`'s `[dependencies]` or `[feature.notebook]`, or a shared
`r/<feature>.txt` spec file — affects every tier that includes it. Rebuild
and test every affected tier, not just the one you were editing.

## The CRAN Repository

`Rprofile.site` ships exactly one R repository — the rolling Posit
Package Manager endpoint `.../noble/latest`. There is no second, no
fallback: pak resolves across every configured repository and returns the
newest version it finds anywhere, so a second repository wouldn't add
redundancy, it would make resolution nondeterministic.

**The repository must be named `CRAN`, and that name is load-bearing.**
pkgcache injects its own rolling `cran.rstudio.com` whenever
`getOption("repos")` contains no entry by that name — so configuring PPM
under any other name leaves it inert while looking correct. Measured at
snapshot `2026-06-01`, where that snapshot offers ggpubr 0.6.3: `c(PPM =
snap)` resolves 1.0.0 from `cran.rstudio.com`, and `c(CRAN = snap)`
resolves 0.6.3 from the snapshot instead. Separately, `Rprofile.site`
also sets `HTTPUserAgent` — that's what makes PPM serve binaries instead
of building from source: 5.5s versus 1m49s for the same resolve.
`options(pkg.use_bioconductor = FALSE)` closes the same hole for the five
Bioconductor repositories pak would otherwise add; no package in any tier
is of Bioconductor origin.

Determinism doesn't come from a frozen date here — it comes from CI
resolving the package list once and handing that same resolution to both
architecture builds, so they can't drift from each other. `PPM` is still
the escape hatch: set it, before starting R or when running the
container, to pin a dated snapshot for reproducible local testing. The
shipped default never does this for you.

**Testing gotcha.** pak resolves in a subprocess that re-reads
`Rprofile.site` from disk, so `options(repos = ...)` typed at an R prompt
never reaches it — a "fix" verified that way will appear to work while
doing nothing. `getOption("repos")` is doubly misleading here: it shows
neither the injected CRAN nor the Bioconductor repos. Ask pak
(`pak::repo_get()`), or install something and inspect where it came from —
`packageDescription("<pkg>")$Repository`, or the `RemoteRepos` field pak
records — never by inspecting `getOption("repos")` in the calling session.

## Pull Request Guidelines

1. **Test locally**: Always run `just test-all` before pushing
2. **Update tests**: Add tests for new functionality
3. **Update documentation**: Update README.md, or this file if needed
4. **Verify CI**: Ensure GitHub Actions pass for all images and platforms
5. **Keep commits atomic**: One logical change per commit

## Architecture Support

All images must support both AMD64 and ARM64. When adding dependencies:

1. Check if the package is available on both platforms
2. Add platform-specific dependencies if needed using `target` sections
3. Test on both platforms (or rely on CI to test both)

## Authentication

Building images requires GitHub authentication for package installation:

- **Preferred**: `gh auth login` (justfile auto-exports token)
- **Alternative**: Set `GITHUB_TOKEN` environment variable

## Getting Help

- **Test framework**: See [Testing](#testing)
- **Issues**: Open an issue at <https://github.com/coursekata/docker-stacks/issues>
