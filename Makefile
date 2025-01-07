shell := bash
current_platform := $(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
git_ref := $(shell git rev-parse --short=7 HEAD)$(shell git diff --quiet || echo "-dirty")

# User variables
export TAG ?= test
export REGISTRY ?= ghcr.io/coursekata
export CACHE_REGISTRY ?= ghcr.io/coursekata/cache
BAKE_ARGS ?=
export GITHUB_TOKEN ?= $(shell gh auth token)
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

# ANSI colors
blue := \033[0;34m
cyan := \033[0;36m
green := \033[0;32m
red := \033[0;31m
yellow := \033[0;33m
reset := \033[0m

# special characters
comma := ,
empty :=
space := $(empty) $(empty)

# functions to print colored text
define print
	@printf "$(1)$(2)$(reset)\n"
endef

define print-info
	$(call print,$(cyan),$(1))
endef

define print-success
	$(call print,$(green),$(1))
endef

define print-error
	$(call print,$(red),$(1))
endef

define print-warning
	$(call print,$(yellow),$(1))
endef

# print an error then exit
define exit-error
	$(call print-error,\n$(1))
	$(if $(2),$(call print-error,  $(2)),)
	@echo
	@exit 1
endef

# ------------------------------------------------------------------------------
# Environment validation
# ------------------------------------------------------------------------------
pixi_envs := $(shell pixi info --json | jq -r '.environments_info[] | .name')

base_envs := foundation base
main_envs := base-r essentials r datascience
deepnote_envs := $(foreach env,$(main_envs),deepnote-$(env))

multiarch_envs := $(base_envs) $(main_envs) ckhub
amd64_envs := $(deepnote_envs) ckcode

define validate-env
	$(eval valid_envs := $(1))
	$(eval error_str := Invalid $(2) environment)
	$(eval info_str := Valid environments are: $(subst $(space),$(comma)$(space),$(valid_envs)))
	$(if $(filter $(3),$(valid_envs)),,$(call exit-error,$(error_str),$(info_str)))
endef

define validate-pixi-env
	$(call validate-env,$(pixi_envs),Pixi,$(1))
endef

define validate-multiarch-env
	$(call validate-env,$(multiarch_envs),multiarch,$(1))
endef

define validate-amd64-env
	$(call validate-env,$(multiarch_envs) $(amd64_envs),AMD64,$(1))
endef

define validate-arm64-env
	$(call validate-env,$(multiarch_envs),ARM64,$(1))
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

img-list: ## List built images
	@echo "Listing $(REGISTRY) images ..."
	docker images "*$(REGISTRY)/*"
img-rm: ## Remove built images
	@echo "Removing $(REGISTRY) images ..."
	-docker rmi --force $(shell docker images --quiet "*$(REGISTRY)/*") 2> /dev/null
img-rm-dang: ## Remove built dangling images (tagged None)
	@echo "Removing dangling images ..."
	-docker rmi --force $(shell docker images -f "dangling=true" --quiet) 2> /dev/null
img-clean: img-rm-dang img-rm ## Clean built and dangling images
	@echo "Cleaned $(REGISTRY) images."

git-sha: ## Get 7-digit git SHA (with '-dirty' if there are uncommitted changes)
	@echo $(git_ref)


define build-image
	$(call print-info,\nBaking $(1) (TAG: $(TAG), REGISTRY: $(REGISTRY), CACHE_REGISTRY: $(CACHE_REGISTRY)))
	@docker buildx bake $(1) $(2) $(BAKE_ARGS)
endef

build/%: ## Build a Docker image
	$(call validate-multiarch-env,$(*))
	$(call build-image,$(*))
build-arm64/%: ## Build a Docker image for ARM64 architecture
	$(call validate-arm64-env,$(*))
	$(call build-image,$(*)-arm64,--load)
build-amd64/%: ## Build a Docker image for AMD64 architecture
	$(call validate-amd64-env,$(*))
	$(eval recipe := $(if $(filter $(*),$(multiarch_envs)),$(*)-amd64,$(*)))
	$(call build-image,$(recipe),--load)
build-all-arm64: $(addprefix build-arm64/,$(multiarch_envs)) ## Build all Docker images for ARM64 architecture
build-all-amd64: $(addprefix build-amd64/,$(multiarch_envs)) $(addprefix build-amd64/,$(amd64_envs)) ## Build all Docker images for AMD64 architecture
build-all: build-all-arm64 build-all-amd64 ## Build all Docker images for ARM64 and AMD64 architectures

shell-amd64/%: ## Run container and open bash shell for amd64 architecture
	$(call validate-amd64-env,$(*))
	$(eval suffix := $(if $(filter $(*),$(multiarch_envs)),-amd64,))
	docker run -it --rm --platform=linux/amd64 $(REGISTRY)/$(*):$(TAG)$(suffix) $(shell)
shell-arm64/%: ## Run container and open bash shell for arm64 architecture
	$(call validate-arm64-env,$(*))
	$(eval suffix := $(if $(filter $(*),$(multiarch_envs)),-arm64,))
	docker run -it --rm --platform=linux/arm64 $(REGISTRY)/$(*):$(TAG)$(suffix) $(shell)

run-amd64/%: ## Run container for amd64 architecture
	$(call validate-amd64-env,$(*))
	docker run -it --rm --platform=linux/amd64 -p=8888:8888 $(REGISTRY)/$(*):$(TAG)
run-arm64/%: ## Run container for arm64 architecture
	$(call validate-arm64-env,$(*))
	$(eval suffix := $(if $(filter $(*),$(multiarch_envs)),-arm64,))
	docker run -it --rm --platform=linux/arm64 -p=8888:8888 $(REGISTRY)/$(*):$(TAG)$(suffix)
