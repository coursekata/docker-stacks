DS_OWNER ?= ghcr.io/coursekata

SHELL := bash
GITHUB_TOKEN ?= $(shell gh auth token)
CURRENT_PLATFORM := $(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
VALID_ENVS := $(shell pixi info --json | jq -r '.environments_info[] | select(.name != "default") | .name')

export GITHUB_TOKEN
export DOCKER_BUILDKIT:=1
export DOCKER_CLI_EXPERIMENTAL=enabled

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

# Terminal colors and utilities
success := $(shell tput setaf 2)
info := $(shell tput setaf 4)
error := $(shell tput setaf 1)
sgr0 := $(shell tput sgr0)
comma := ,

# Validate PIXI_ENV
define validate_env
	@if ! echo "$(VALID_ENVS)" | grep -q -w "$(1)"; then \
		printf "\n"; \
		printf "$(error)Error: Invalid PIXI_ENV '$(1)'\n"; \
		printf "  Valid environments are: $(VALID_ENVS)$(sgr0)\n"; \
		printf "\n"; \
		exit 1; \
	fi
endef

# Build an image for a given platform
define build_image
	$(call validate_env,$(1))
	@printf '\n$(info)Building $(DS_OWNER)/$(1)$(3)$(sgr0)\n'
	docker buildx build --tag $(DS_OWNER)/$(1)$(3) \
		--platform=$(2) \
	  --build-arg=PIXI_ENV="$(1)" \
	  --secret=id=github_token,env=GITHUB_TOKEN \
		--cache-to=type=registry,ref=$(DS_OWNER)/$(1)$(3) \
		--cache-from=type=registry,ref=$(DS_OWNER)/$(1):aarch64 \
		--cache-from=type=registry,ref=$(DS_OWNER)/$(1):amd64 \
		--load .
	@printf "Docker image $(DS_OWNER)/$(1) built successfully for $(1).\n"
endef

# Test an image for a given platform
define test_image
	$(call validate_env,$(1))
	@printf '\n$(info)Testing $(DS_OWNER)/$(1)$(3)$(sgr0)\n'
	@docker run --rm \
		--platform="$(2)" \
		--mount=type=bind,source="./tests/test-packages.sh",target=/tmp/test-packages.sh \
		--mount=type=bind,source="./tests/packages.txt",target=/tmp/packages.txt \
		--mount=type=bind,source="./tests/$(notdir $(1)).sh",target=/tmp/test.sh \
		"$(DS_OWNER)/$(1)$(3)" $(SHELL) /tmp/test.sh
endef

# Run an image for a given platform
define run_image
	$(call validate_env,$(1))
	docker run -it --rm --platform=$(2) -p=8888:8888 $(2) $(DS_OWNER)/$(1)$(3)
endef

# Run an image and open a shell for a given platform
define run_shell
	$(call validate_env,$(1))
	docker run -it --rm --platform=$(2) $(DS_OWNER)/$(1)$(3) $(SHELL)
endef


# ------------------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------------------

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help:
	@echo "coursekata/docker-stacks"
	@echo "====================="
	@echo "Replace % with a Pixi environment name (e.g., make build/base-r)"
	@echo
	@grep -E '^[a-zA-Z0-9_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build/%: ## Build for default architecture
	$(call build_image,$*,$(CURRENT_PLATFORM),)
build-amd64/%: ## Build for amd64 architecture
	$(call build_image,$*,linux/amd64,:amd64)
build-aarch64/%: ## Build for aarch64 architecture
	$(call build_image,$*,linux/aarch64,:aarch64)
build-multiarch/%: ## Build for all architectures simultaneously
	$(call build_image,$*,linux/amd64$(comma)linux/aarch64,:latest)

build-all: $(foreach I, $(VALID_ENVS), build/$(I)) ## Build all images for default architecture
build-all-amd64: $(foreach I, $(VALID_ENVS), build-amd64/$(I)) ## Build all images for amd64 architecture
build-all-aarch64: $(foreach I, $(VALID_ENVS), build-aarch64/$(I)) ## Build all images for aarch64 architecture
build-all-multiarch: $(foreach I, $(VALID_ENVS), build-amd64/$(I) build-aarch64/$(I)) ## Build all images for all architectures

test/%: build/% ## Test image for default architecture
	$(call test_image,$*,$(CURRENT_PLATFORM),)
test-amd64/%: build-amd64/% ## Test image for amd64 architecture
	$(call test_image,$*,linux/amd64,:amd64)
test-aarch64/%: build-aarch64/% ## Test image for aarch64 architecture
	$(call test_image,$*,linux/aarch64,:aarch64)
test-multiarch/%: test-amd64/% test-aarch64/% ## Test image for all architectures
	@

test-all: $(foreach I, $(VALID_ENVS), test/$(I)) ## Test all images for default architecture
test-all-amd64: $(foreach I, $(VALID_ENVS), test-amd64/$(I)) ## Test all images for amd64 architecture
test-all-aarch64: $(foreach I, $(VALID_ENVS), test-aarch64/$(I)) ## Test all images for aarch64 architecture
test-all-multiarch: $(foreach I, $(VALID_ENVS), test-amd64/$(I) test-aarch64/$(I)) ## Test all images for all architectures

shell/%: ## Run container and open bash shell for default architecture
	$(call run_shell,$*,$(CURRENT_PLATFORM),)
shell-amd64/%: ## Run container and open bash shell for amd64 architecture
	$(call run_shell,$*,linux/amd64,:amd64)
shell-aarch64/%: ## Run container and open bash shell for aarch64 architecture
	$(call run_shell,$*,linux/aarch64,:aarch64)

run/%: ## Run container for default architecture
	$(call run_image,$*,$(CURRENT_PLATFORM),)
run-amd64/%: ## Run container for amd64 architecture
	$(call run_image,$*,linux/amd64,:amd64)
run-aarch64/%: ## Run container for aarch64 architecture
	$(call run_image,$*,linux/aarch64,:aarch64)

img-clean: img-rm-dang img-rm ## clean built and dangling images
img-list: ## list images
	@echo "Listing $(DS_OWNER) images ..."
	docker images "*$(DS_OWNER)/*"
img-rm: ## remove images
	@echo "Removing $(DS_OWNER) images ..."
	-docker rmi --force $(shell docker images --quiet "*$(DS_OWNER)/*") 2> /dev/null
img-rm-dang: ## remove dangling images (tagged None)
	@echo "Removing dangling images ..."
	-docker rmi --force $(shell docker images -f "dangling=true" --quiet) 2> /dev/null
