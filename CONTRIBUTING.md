# Contributing to CourseKata Docker Stacks

This guide covers development workflows, testing, CI/CD, and contribution guidelines.

## Development Workflow

### Prerequisites

- Docker Desktop or Docker Engine
- GitHub CLI (`gh`) or `GITHUB_TOKEN` environment variable
- Make
- Pixi (optional, for local dependency management)
- [prek](https://github.com/anthropics/prek) for pre-commit hooks

### Setting Up Pre-commit Hooks

This project uses pre-commit hooks to keep generated files in sync. Install prek and set up the hooks:

```bash
# Install prek (requires pipx or pip)
pipx install prek

# Install the pre-commit hooks
prek install
```

The hooks will automatically regenerate `pak-scripts/*.R` files when `rpixi.toml` changes.

### Building Images Locally

Use Makefile targets to build images:

```bash
# Build for your current architecture
make build/r-notebook

# Build for specific architectures
make build-amd64/r-notebook
make build-arm64/datascience-notebook

# Build all images
make build-all
```

The build system automatically pulls cache from `ghcr.io/coursekata/*` if `DS_OWNER` is set.

### Testing Images

Always test after building:

```bash
# Test after building
make test/r-notebook
make test-amd64/essentials-notebook

# Test all images
make test-all
```

See `scripts/tests/README.md` for details on the test framework architecture.

### Running Containers

```bash
# Run container and get shell access
make shell/r-notebook

# Run container normally (starts Jupyter)
make run/datascience-notebook
```

### Direct Script Usage

You can also use the scripts directly:

```bash
# Build
./scripts/build-image.sh --image r-notebook --platform linux/amd64 --tag my-tag

# Test
./scripts/test-image.sh --image r-notebook --platform linux/amd64 --tag my-tag

# Run shell
./scripts/run-shell.sh --image my-tag --platform linux/amd64

# Run Jupyter
./scripts/run-container.sh --image my-tag --platform linux/amd64
```

## Testing

### Test Architecture

Tests run inside Docker containers to validate that images are correctly configured. The test suite:

1. Mounts the `scripts/` directory into the container at `/tmp/scripts`
2. Executes `scripts/tests/run-tests.sh` with the environment name
3. Tests run in logical order: fast tests (environment checks) first, slow tests (package validation) last

### Test Execution Flow

```txt
make test/r-notebook
  └─> ./scripts/test-image.sh
        ├─> Validates environment name against pixi.toml
        ├─> Generates Python package list on host
        └─> Runs docker with mounts:
              - ./scripts → /tmp/scripts
              - ./pixi.toml → /home/jovyan/pixi.toml
              - ./rpixi.toml → /home/jovyan/rpixi.toml
              - Generated package list → /tmp/python-packages.txt
            └─> bash /tmp/scripts/tests/run-tests.sh r-notebook
```

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
   - Health check

3. **Package Installation**:
   - Python packages: installation check (`pip show`) and import validation
   - R packages: loading via `library()` and special configurations (cmdstanr)

### Adding Tests

See `scripts/tests/README.md` for detailed instructions on adding tests to existing modules, creating new test modules, and modifying the test runner.

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

**Solution**: Run `make test/base-r-notebook` locally to cache the base layer to the registry. This allows GitHub Actions to skip building the base stage and use the cached layer.

#### Test Failures

If tests fail in CI:

1. Pull the image locally: `docker pull ghcr.io/coursekata/<image>:cache-<platform>`
2. Run tests locally: `make test/<image>`
3. Debug with `TEST_DEBUG=1` environment variable
4. Run individual test modules as shown in `scripts/tests/README.md`

## Modifying Dependencies

### Conda Packages (Python, R base, system packages)

1. Run `pixi add --feature <feature-name> <package-name>` to add the package and update the lock file
   - Note you can also scope it to a platform with `--platform linux-amd64` or `--platform linux-aarch64`
2. Rebuild and test: `make build/<image> && make test/<image>`

### R Packages

1. Edit `rpixi.toml` in the appropriate feature section
2. Determine if you can add it via `pixi add` as well, but remember that `rpixi.toml` is the source of truth
   for R packages: adding via `pixi add` is only improve install times
3. Validate syntax: `./scripts/rpixi.R validate`
4. Rebuild and test: `make build/<image> && make test/<image>`

Example:

```toml
[feature.essentials.dependencies]
coursekata = { force = true }
testwhat = { github = "coursekata/testwhat", tag = "v4.11.3.2" }
```

See `rpixi.toml` for package source examples (CRAN, GitHub, custom repos).

## Image Hierarchy

Images build on one another in this order:

1. **base-r-notebook**: Python + R + Jupyter
2. **essentials-notebook**: + CourseKata packages
3. **r-notebook**: + Extended R packages
4. **datascience-notebook**: + Python data science packages

**Important**: Changes to a base image affect all downstream images. When modifying `base-r-notebook`, rebuild and test all dependent images.

## Pull Request Guidelines

1. **Test locally**: Always run `make test-all` before pushing
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

- **Preferred**: `gh auth login` (Makefile auto-exports token)
- **Alternative**: Set `GITHUB_TOKEN` environment variable

## Getting Help

- **Test framework**: See `scripts/tests/README.md`
- **Issues**: Open an issue at <https://github.com/coursekata/docker-stacks/issues>
