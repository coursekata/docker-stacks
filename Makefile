DS_OWNER ?= ghcr.io/coursekata

SHELL := bash
GITHUB_TOKEN ?= $(shell gh auth token)
CURRENT_PLATFORM := $(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
VALID_ENVS := $(shell pixi info --json | jq -r '.environments_info[] | select(.name != "default") | .name')

export GITHUB_TOKEN
export DS_OWNER


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
	@echo ""
	./scripts/build-image.sh --image $* --platform $(CURRENT_PLATFORM) --tag $(DS_OWNER)/$*
build-amd64/%: ## Build for amd64 architecture
	@echo ""
	./scripts/build-image.sh --image $* --platform linux/amd64 --tag $(DS_OWNER)/$*:amd64
build-arm64/%: ## Build for arm64 architecture
	@echo ""
	./scripts/build-image.sh --image $* --platform linux/arm64 --tag $(DS_OWNER)/$*:arm64

build-all: $(foreach I, $(VALID_ENVS), build/$(I)) ## Build all images for default architecture
build-all-amd64: $(foreach I, $(VALID_ENVS), build-amd64/$(I)) ## Build all images for amd64 architecture
build-all-arm64: $(foreach I, $(VALID_ENVS), build-arm64/$(I)) ## Build all images for arm64 architecture

test/%: build/% ## Test image for default architecture
	@echo ""
	./scripts/test-image.sh --image $* --platform $(CURRENT_PLATFORM) --tag $(DS_OWNER)/$*
test-amd64/%: build-amd64/% ## Test image for amd64 architecture
	@echo ""
	./scripts/test-image.sh --image $* --platform linux/amd64 --tag $(DS_OWNER)/$*:amd64
test-arm64/%: build-arm64/% ## Test image for arm64 architecture
	@echo ""
	./scripts/test-image.sh --image $* --platform linux/arm64 --tag $(DS_OWNER)/$*:arm64

test-all: $(foreach I, $(VALID_ENVS), test/$(I)) ## Test all images for default architecture
test-all-amd64: $(foreach I, $(VALID_ENVS), test-amd64/$(I)) ## Test all images for amd64 architecture
test-all-arm64: $(foreach I, $(VALID_ENVS), test-arm64/$(I)) ## Test all images for arm64 architecture

shell/%: build/% ## Run container and open bash shell for default architecture
	./scripts/run-shell.sh --image $(DS_OWNER)/$* --platform $(CURRENT_PLATFORM)
shell-amd64/%: build-amd64/% ## Run container and open bash shell for amd64 architecture
	./scripts/run-shell.sh --image $(DS_OWNER)/$*:amd64 --platform linux/amd64
shell-arm64/%: build-arm64/% ## Run container and open bash shell for arm64 architecture
	./scripts/run-shell.sh --image $(DS_OWNER)/$*:arm64 --platform linux/arm64

run/%: ## Run container for default architecture
	./scripts/run-container.sh --image $(DS_OWNER)/$* --platform $(CURRENT_PLATFORM)
run-amd64/%: ## Run container for amd64 architecture
	./scripts/run-container.sh --image $(DS_OWNER)/$*:amd64 --platform linux/amd64
run-arm64/%: ## Run container for arm64 architecture
	./scripts/run-container.sh --image $(DS_OWNER)/$*:arm64 --platform linux/arm64

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
