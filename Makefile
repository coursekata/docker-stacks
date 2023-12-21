# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
# Adapted from https://github.com/jupyter/docker-stacks/blob/31f4c98405c9dea535f017344014061d510cb53c/Makefile

SHELL:=bash
REGISTRY?=ghcr.io
OWNER?=coursekata
BUILDER_NAME?=docker-stacks-builder
DOCKER_BUILD_ARGS?=

# Need to list the images in build dependency order
ALL_IMAGES:= \
	base-r-notebook \
	essentials-notebook \
	r-notebook \
	datascience-notebook

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1


# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help:
	@echo "coursekata/docker-stacks"
	@echo "====================="
	@echo "Replace % with a stack directory name (e.g., make build/base-r-notebook)"
	@echo
	@grep -E '^[a-zA-Z0-9_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'



create-builder:
	@if ! docker buildx ls | grep -q $(BUILDER_NAME); then \
		@docker buildx create --name=$(BUILDER_NAME) --driver=docker-container --driver-opt=network=host; \
	fi
	docker buildx use $(BUILDER_NAME)
build/%: ## build the latest image for a stack using the system's architecture
	docker build $(DOCKER_BUILD_ARGS) --rm --force-rm \
	--tag "$(REGISTRY)/$(OWNER)/$(notdir $@):latest" \
	--build-arg REGISTRY="$(REGISTRY)" \
	--build-arg OWNER="$(OWNER)" \
	"./$(notdir $@)"
	@echo
	@echo -n "Built image size: "
	@docker images "$(REGISTRY)/$(OWNER)/$(notdir $@):latest" --format "{{.Size}}"
	@echo
build-multiarch/%: create-builder ## build the latest image using a multi-arch builder
	docker buildx build $(DOCKER_BUILD_ARGS) --rm --force-rm \
	--tag "$(REGISTRY)/$(OWNER)/$(notdir $@):latest" \
	--platform linux/amd64,linux/arm64 \
	--build-arg REGISTRY="$(REGISTRY)" \
	--build-arg OWNER="$(OWNER)" \
	"./$(notdir $@)"
	@echo
	@echo -n "Built image size: "
	@docker images "$(REGISTRY)/$(OWNER)/$(notdir $@):latest" --format "{{.Size}}"
	@echo
build-all: $(foreach I, $(ALL_IMAGES), build/$(I)) ## build all stacks
build-all-multiarch: $(foreach I, $(ALL_IMAGES), build-multiarch/$(I)) ## build all stacks for multiple architectures



cont-clean-all: cont-stop-all cont-rm-all ## clean all containers (stop + rm)
cont-stop-all: ## stop all containers
	@echo "Stopping all containers ..."
	-docker stop --time 0 $(shell docker ps --all --quiet) 2> /dev/null
cont-rm-all: ## remove all containers
	@echo "Removing all containers ..."
	-docker rm --force $(shell docker ps --all --quiet) 2> /dev/null



img-clean: img-rm-dang img-rm ## clean built and dangling images
img-list: ## list images
	@echo "Listing $(OWNER) images ..."
	docker images "$(OWNER)/*"
	docker images "*/$(OWNER)/*"
img-rm: ## remove images
	@echo "Removing $(OWNER) images ..."
	-docker rmi --force $(shell docker images --quiet "$(OWNER)/*") 2> /dev/null
	-docker rmi --force $(shell docker images --quiet "*/$(OWNER)/*") 2> /dev/null
img-rm-dang: ## remove dangling images (tagged None)
	@echo "Removing dangling images ..."
	-docker rmi --force $(shell docker images -f "dangling=true" --quiet) 2> /dev/null



pull/%: ## pull an image
	docker pull "$(REGISTRY)/$(OWNER)/$(notdir $@)"
pull-all: $(foreach I, $(ALL_IMAGES), pull/$(I)) ## pull all images



run/%: ## run a stack on port 8888
	docker run -it --rm -p 8888:8888 "$(REGISTRY)/$(OWNER)/$(notdir $@)"
run-shell/%: ## run a bash in interactive mode in a stack
	docker run -it --rm "$(REGISTRY)/$(OWNER)/$(notdir $@)" $(SHELL)
run-sudo-shell/%: ## run a bash in interactive mode as root in a stack
	docker run -it --rm --user root "$(REGISTRY)/$(OWNER)/$(notdir $@)" $(SHELL)



test/%: ## test a stack
	@echo "Testing $(notdir $@) ..."
	@docker run --rm --mount=type=bind,source="./tests/$(notdir $@).sh",target=/tmp/test.sh \
	"$(REGISTRY)/$(OWNER)/$(notdir $@)" $(SHELL) /tmp/test.sh
	@echo
test-all: $(foreach I, $(ALL_IMAGES), test/$(I)) ## test all stacks
