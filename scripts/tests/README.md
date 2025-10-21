# Test Suite

This directory contains the test suite for CourseKata Docker Stack images. The test suite follows these principles:

- **Fast feedback**: Quick tests run first (environment, permissions) before slower tests (packages)
- **Comprehensive coverage**: Test all critical functionality (packages, Jupyter, kernels, configuration)
- **Parallel execution**: Package import/load tests run in parallel for speed
- **Clear output**: Color-coded, hierarchical output with summaries
- **Modular design**: Reusable test modules shared across image types
- **Consistent testing**: All images tested identically via generic runner

## Structure

```txt
scripts/tests/
├── run-tests.sh           # Generic test runner (takes environment name)
└── lib/                   # Modular test libraries
    ├── helpers.sh         # Test utilities, assertions, formatting
    ├── system.sh          # System and environment tests
    ├── jupyter.sh         # Jupyter and kernel tests
    ├── packages-python.sh # Python package tests
    └── packages-r.sh      # R package tests
```

## Test Modules

### `helpers.sh`

Common utilities, logging, assertions, and test state management:

- Color formatting and output functions
- Test counters and summary reporting (`TEST_TOTAL`, `TEST_PASSED`, `TEST_FAILED`, `TEST_SKIPPED`)
- Assertion functions: `assert_success`, `assert_file_exists`, `assert_equals`, etc.
- Utility functions: timing, parallel execution, temp directories
- `print_header()`: Dynamic box generation for test suite headers

### `system.sh`

System environment and configuration tests:

- **User & Permissions**: User setup (jovyan), file permissions, write access
- **Environment Variables**: CONDA_DIR, R_HOME, Python paths, etc.
- **Python Environment**: python3, pip3, version checks
- **R Environment**: R version, Rprofile, CRAN/PPM repository configuration

### `jupyter.sh`

Jupyter and kernel tests:

- Jupyter server installation and configuration
- Kernel availability (IR and Python3)
- IRkernel registration verification
- Default kernel configuration
- Health check validation

### `packages-python.sh`

Python package tests:

- Extracts Python packages from `pixi.toml` via `scripts/list-python-packages.sh`
- Tests package installation via `pip show`
- Tests package imports (parallel execution for speed)

### `packages-r.sh`

R package tests:

- Extracts R packages from `rpixi.toml` via `scripts/rpixi.R list`
- Tests package loading via `library()`
- Parallel loading tests for performance
- Special handling for cmdstanr configuration (CMDSTAN env var)

## Test Runner

`run-tests.sh` is a generic test runner that handles all environments:

```bash
# Usage
./run-tests.sh <environment-name>

# Example
./run-tests.sh r-notebook
```

**Features**:

- Takes environment name as argument
- Runs the same test suite for all images (ensuring consistency)
- Special handling for environment-specific cases (e.g., CMDSTAN for datascience-notebook)
- Sources all test modules and executes tests in logical order

## Test Framework Patterns

### Test State Management

Tests use global counters to track results:

```bash
TEST_TOTAL=$((TEST_TOTAL + 1))    # Increment total count
TEST_PASSED=$((TEST_PASSED + 1))  # Increment pass count
TEST_FAILED=$((TEST_FAILED + 1))  # Increment fail count
```

### Relative Path Resolution

Test modules use relative paths for foolproof script discovery:

```bash
local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
local rpixi_path="${lib_dir}/../../rpixi.R"
```

### Parallel Execution

Package tests run in parallel for performance:

- Python imports tested concurrently
- R library() loads tested concurrently
- Results collected from temp files

## Adding New Tests

### To an existing module

1. Open the appropriate test module in `lib/`
2. Add your test function following the naming convention `test_*`
3. Use helper functions from `helpers.sh` for assertions
4. Increment test counters appropriately
5. Export the function at the bottom of the module

Example:

```bash
test_my_feature() {
  TEST_TOTAL=$((TEST_TOTAL + 1))

  if my_check; then
    TEST_PASSED=$((TEST_PASSED + 1))
    success "My feature works"
  else
    TEST_FAILED=$((TEST_FAILED + 1))
    error "My feature failed"
  fi
}

export -f test_my_feature
```

### Creating a new module

1. Create a new file in `lib/` (e.g., `custom.sh`)
2. Source `helpers.sh` at the top
3. Define test functions with `test_*` prefix
4. Export functions at the bottom
5. Source your module in `run-tests.sh`
6. Call your test functions in the appropriate order

### Modifying the test runner

1. Edit `run-tests.sh`
2. Source any new test modules needed
3. Call test functions in logical order (fast tests first, slow tests last)
4. Add environment-specific special cases if needed

## Debugging

### Enable verbose output

Set `TEST_DEBUG=1` to see detailed debug information:

```bash
docker run --rm -e TEST_DEBUG=1 --platform=linux/amd64 \
  --mount=type=bind,source="./scripts",target=/tmp/scripts \
  --mount=type=bind,source="./pixi.toml",target=/home/jovyan/pixi.toml \
  --mount=type=bind,source="./rpixi.toml",target=/home/jovyan/rpixi.toml \
  ghcr.io/coursekata/base-r-notebook \
  bash /tmp/scripts/tests/run-tests.sh base-r-notebook
```

### Run individual modules

You can run individual test modules directly:

```bash
docker run --rm -it --platform=linux/amd64 \
  --mount=type=bind,source="./scripts",target=/tmp/scripts \
  ghcr.io/coursekata/base-r-notebook bash

# Inside container:
source /tmp/scripts/tests/lib/helpers.sh
source /tmp/scripts/tests/lib/system.sh
test_user_setup
test_r_environment
```
