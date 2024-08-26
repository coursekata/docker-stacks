# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
# Adapted from https://github.com/jupyter/docker-stacks/blob/31f4c98405c9dea535f017344014061d510cb53c/Makefile

SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1
# Activate experimental mode
export DOCKER_CLI_EXPERIMENTAL=enabled
# Load the GitHub Personal Access Token from the environment
export github_token:=$(shell gh auth token)

# Check if the local registry is running
LOCAL_REGISTRY_UP := $(shell docker ps --filter name="^registry$$" --format "{{.Names}}" | grep -q registry && echo true || echo false)
# Determine the port for the local registry (either the running one or one between 5000 and 6000)
LOCAL_REGISTRY_PORT := $(shell \
	if [ "$(LOCAL_REGISTRY_UP)" = "true" ]; then \
		docker port registry | cut -d: -f2; \
	else \
		ports=($$(seq 5000 6000)); \
		for port in $${ports[@]}; do \
			if ! nc -z localhost $$port > /dev/null 2>&1; then \
				echo $$port; \
				break; \
			fi; \
		done; \
	fi)
LOCAL_REGISTRY:=localhost:$(LOCAL_REGISTRY_PORT)

DS_REGISTRY?=$(LOCAL_REGISTRY)
DS_OWNER?=coursekata
DS_BUILDER_NAME?=docker-stacks-builder
DS_BUILD_ARGS?=
DS_RUN_ARGS?=

# Need to list the images in build dependency order
ALL_IMAGES:= \
	base-r-notebook \
	essentials-notebook \
	r-notebook \
	datascience-notebook

# get current platform and set to either linux/amd64 or linux/arm64
CURRENT_PLATFORM := $(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
CURRENT_ARCH := $(shell docker version --format '{{.Server.Arch}}')
COMMON_BUILD_ARGS?=--build-arg REGISTRY=$(DS_REGISTRY) --build-arg DS_OWNER=$(DS_OWNER)

# terminal colors
success := $(shell tput setaf 2)
info := $(shell tput setaf 4)
sgr0 := $(shell tput sgr0)

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
	@if ! docker buildx ls | grep -q $(DS_BUILDER_NAME); then \
		printf '$(info)Creating builder $(DS_BUILDER_NAME)$(sgr0)\n'; \
		docker buildx create --name=$(DS_BUILDER_NAME) \
			--driver=docker-container \
			--driver-opt=network=host \
			--driver-opt=env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 ; \
		docker buildx inspect --bootstrap $(DS_BUILDER_NAME); \
	fi
	@docker buildx use $(DS_BUILDER_NAME)
	@printf '$(success)Using builder $(DS_BUILDER_NAME)$(sgr0)\n'
create-registry:
	@if [ ! "$(LOCAL_REGISTRY_UP)" = "true" ]; then \
		printf '$(info)Local registry not running, starting one on port $(LOCAL_REGISTRY_PORT)$(sgr0) \n'; \
		docker run -d --rm --name registry -p $(LOCAL_REGISTRY_PORT):5000 registry:2; \
	fi;
	@printf '$(success)Using registry $(LOCAL_REGISTRY)$(sgr0)\n'
setup-docker: create-builder create-registry

# build an image for a given platform
define build_image
	@printf '\n$(info)Building $(notdir $(2)) ($(1))$(sgr0)\n'
	docker buildx build $(COMMON_BUILD_ARGS) $(DS_BUILD_ARGS) \
		--platform $(1) \
		--secret id=github_token \
		--tag "$(LOCAL_REGISTRY)/$(DS_OWNER)/$(notdir $(2))" \
		--cache-from type=registry,ref="$(LOCAL_REGISTRY)/$(DS_OWNER)/$(notdir $(2))" \
		--cache-to type=inline \
		--push \
		"./$(notdir $(2))"

	@printf '\n$(info)Pulling $(notdir $(2)) from build cache...$(sgr0)\n'
	@DOCKER_CLI_HINTS=false \
		docker pull --platform="$(shell echo $(1) | cut -d, -f1)" \
		"$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $(2))"

	@printf '\n$(success)Built $(notdir $(2)) ($(1))$(sgr0)\n'
	@docker images "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $(2))"
endef

platforms=linux/amd64,linux/arm64
build/%: setup-docker ## build the latest image for a stack using the system's architecture
	$(call build_image,$(CURRENT_PLATFORM),$@)
build-amd64/%: setup-docker ## build the latest image for a stack using amd64 architecture
	$(call build_image,linux/amd64,$@)
build-arm64/%: setup-docker ## build the latest image for a stack using arm64 architecture
	$(call build_image,linux/arm64,$@)
build-multiarch/%: setup-docker ## build the latest image using a multi-arch builder
	$(call build_image,$(platforms),$@)
build-all: $(foreach I, $(ALL_IMAGES), build/$(I)) ## build all stacks
build-multiarch-all: $(foreach I, $(ALL_IMAGES), build-multiarch/$(I)) ## build all stacks for all architectures

# test an image for a given platform
define test_image
	@printf '\n$(info)Pulling $(notdir $(2)) ($(1))$(sgr0)\n'
	@DOCKER_CLI_HINTS=false \
		docker pull --platform "$(1)" "$(3)/$(DS_OWNER)/$(notdir $(2))"

	@echo
	@printf '$(info)Testing $(notdir $(2)) ($(1))$(sgr0)\n'
	@docker run $(DS_RUN_ARGS) --rm \
		--platform="$(1)" \
		--mount=type=bind,source="./tests/test-r-packages.sh",target=/tmp/test-r-packages.sh \
		--mount=type=bind,source="./tests/test-python-packages.sh",target=/tmp/test-python-packages.sh \
		--mount=type=bind,source="./tests/$(notdir $(2)).sh",target=/tmp/test.sh \
		"$(3)/$(DS_OWNER)/$(notdir $(2))" $(SHELL) /tmp/test.sh
endef

test/%: ## test a stack
	$(call test_image,$(CURRENT_PLATFORM),$@,$(DS_REGISTRY))
test-amd64/%: ## test a stack using amd64 architecture
	$(call test_image,linux/amd64,$@,$(DS_REGISTRY))
test-arm64/%: ## test a stack using arm64 architecture
	$(call test_image,linux/arm64,$@,$(DS_REGISTRY))
test-multiarch/%: test-amd64/% test-arm64/% ## test a stack for all architectures
	@:
test-all: $(foreach I, $(ALL_IMAGES), test/$(I)) ## test all stacks
test-multiarch-all: $(foreach I, $(ALL_IMAGES), test-multiarch/$(I)) ## test all stacks for all architectures

build-test/%: build/% test/% ## build and test a stack
	@:
build-test-amd64/%: build-amd64/% test-amd64/% ## build and test a stack using amd64 architecture
	@:
build-test-arm64/%: build-arm64/% test-arm64/% ## build and test a stack using arm64 architecture
	@:
build-test-multiarch/%: build-multiarch/% test-multiarch/% ## build and test a stack for all architectures
	@:
build-test-all: $(foreach I, $(ALL_IMAGES), build-test/$(I)) ## build and test all stacks
build-test-multiarch-all: $(foreach I, $(ALL_IMAGES), build-test-multiarch/$(I)) ## build and test all stacks for all architectures

cont-clean-all: cont-stop-all cont-rm-all ## clean all containers (stop + rm)
cont-stop-all: ## stop all containers
	@echo "Stopping all containers ..."
	-docker stop --time 0 $(shell docker ps --all --quiet) 2> /dev/null
cont-rm-all: ## remove all containers
	@echo "Removing all containers ..."
	-docker rm --force $(shell docker ps --all --quiet) 2> /dev/null

cache-clean: ## clean cache mounts
	@echo "Cleaning cache mounts ..."
	-docker builder prune --filter type=exec.cachemount --builder $(DS_BUILDER_NAME)

img-clean: img-rm-dang img-rm ## clean built and dangling images
img-list: ## list images
	@echo "Listing $(DS_OWNER) images ..."
	docker images "$(DS_OWNER)/*"
	docker images "*/$(DS_OWNER)/*"
img-rm: ## remove images
	@echo "Removing $(DS_OWNER) images ..."
	-docker rmi --force $(shell docker images --quiet "$(DS_OWNER)/*") 2> /dev/null
	-docker rmi --force $(shell docker images --quiet "*/$(DS_OWNER)/*") 2> /dev/null
img-rm-dang: ## remove dangling images (tagged None)
	@echo "Removing dangling images ..."
	-docker rmi --force $(shell docker images -f "dangling=true" --quiet) 2> /dev/null

run/%: ## run a stack on port 8888
	docker run -it --rm -p 8888:8888 $(DS_RUN_ARGS) "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)"
run-amd64/%: ## run a stack on port 8888 using amd64 architecture
	docker run -it --rm -p 8888:8888 $(DS_RUN_ARGS) --platform linux/amd64 "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)"
run-arm64/%: ## run a stack on port 8888 using arm64 architecture
	docker run -it --rm -p 8888:8888 $(DS_RUN_ARGS) --platform linux/arm64 "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)"

run-shell/%: ## run a bash in interactive mode in a stack
	docker run -it --rm $(DS_RUN_ARGS) "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)" $(SHELL)
run-shell-amd64/%: ## run a bash in interactive mode using amd64 architecture
	docker run -it --rm $(DS_RUN_ARGS) --platform linux/amd64 "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)" $(SHELL)
run-shell-arm64/%: ## run a bash in interactive mode using arm64 architecture
	docker run -it --rm $(DS_RUN_ARGS) --platform linux/arm64 "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)" $(SHELL)

run-sudo-shell/%: ## run a bash in interactive mode as root in a stack
	docker run -it --rm --user root $(DS_RUN_ARGS)  "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)" $(SHELL)
run-sudo-shell-amd64/%: ## run a bash in interactive mode as root using amd64 architecture
	docker run -it --rm --user root $(DS_RUN_ARGS) --platform linux/amd64 "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)" $(SHELL)
run-sudo-shell-arm64/%: ## run a bash in interactive mode as root using arm64 architecture
	docker run -it --rm --user root $(DS_RUN_ARGS) --platform linux/arm64 "$(DS_REGISTRY)/$(DS_OWNER)/$(notdir $@)" $(SHELL)
