shell := bash

# User variables
export TAGS ?= test
export REGISTRY ?= ghcr.io/coursekata
export CACHE_REGISTRY ?= ghcr.io/coursekata/cache
BAKE_ARGS ?=

# Build variables
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled
export GITHUB_TOKEN ?= $(shell gh auth token)
export REVISION ?= $(shell git rev-parse HEAD)
export VERSION ?= sha-$(shell git rev-parse --short HEAD)
export TIMESTAMP ?= $(shell python3 -c "from datetime import datetime, UTC; print(datetime.now(UTC).isoformat(timespec='milliseconds').replace('+00:00', 'Z'))")

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help:
	@echo "coursekata/docker-stacks"
	@echo "====================="
	@echo "Replace % with a Bake target.
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

define build-image
	$(call print-info,\nBaking $(1) (TAG: $(TAGS), REGISTRY: $(REGISTRY), CACHE_REGISTRY: $(CACHE_REGISTRY)))
	@docker buildx bake $(1) $(2) $(BAKE_ARGS)
endef

build/%: ## Build a Docker image
	$(call build-image,$(*))
build-all: build/main build/minimal ## Build all Docker images
build-all-amd64: build/main-amd64 build/minimal ## Build all Docker images for amd64 architecture
build-all-arm64: build/main-arm64 ## Build all Docker images for arm64 architecture

shell-amd64/%: ## Run container and open bash shell for amd64 architecture
	docker run --pull=never -it --rm --platform=linux/amd64 $(REGISTRY)/$(*):$(TAGS)$(suffix) $(shell)
shell-arm64/%: ## Run container and open bash shell for arm64 architecture
	docker run --pull=never -it --rm --platform=linux/arm64 $(REGISTRY)/$(*):$(TAGS)$(suffix) $(shell)

run-amd64/%: ## Run container for amd64 architecture
	docker run --pull=never -it --rm --platform=linux/amd64 -p=8888:8888 $(REGISTRY)/$(*):$(TAGS)
run-arm64/%: ## Run container for arm64 architecture
	docker run --pull=never -it --rm --platform=linux/arm64 -p=8888:8888 $(REGISTRY)/$(*):$(TAGS)
