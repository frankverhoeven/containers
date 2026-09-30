FRANKENPHP_PLATFORM ?= linux/arm64
FRANKENPHP_DEV_IMAGE ?= containers-frankenphp:dev
FRANKENPHP_RUNTIME_IMAGE ?= containers-frankenphp:runtime
FRANKENPHP_RUNTIME_TEST_IMAGE ?= containers-frankenphp:runtime-test

ARGS = $(filter-out $@,$(MAKECMDGOALS))
MAKEFLAGS += --silent

.PHONY: build help

build: ## Build image from the provided Dockerfile
	docker build . -f ${ARGS}

help: ## List available commands
	@grep -E '^[a-zA-Z%_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

%:
	@:

.PHONY: frankenphp-build frankenphp-test frankenphp-size
frankenphp-build: ## Build development, runtime and runtime test images
	docker build --platform $(FRANKENPHP_PLATFORM) --target dev -t $(FRANKENPHP_DEV_IMAGE) -f php/8.5-frankenphp/Dockerfile .
	docker build --platform $(FRANKENPHP_PLATFORM) --target runtime -t $(FRANKENPHP_RUNTIME_IMAGE) -f php/8.5-frankenphp/Dockerfile .
	docker build --platform $(FRANKENPHP_PLATFORM) --target runtime-test -t $(FRANKENPHP_RUNTIME_TEST_IMAGE) -f php/8.5-frankenphp/Dockerfile .

frankenphp-test: ## Verify development and runtime variants
	docker run --rm --platform $(FRANKENPHP_PLATFORM) --entrypoint sh -v $(CURDIR)/tests:/tests:ro $(FRANKENPHP_DEV_IMAGE) /tests/frankenphp-test.sh
	docker run --rm --platform $(FRANKENPHP_PLATFORM) --entrypoint sh -e IMAGE_VARIANT=runtime -v $(CURDIR)/tests:/tests:ro $(FRANKENPHP_RUNTIME_TEST_IMAGE) /tests/frankenphp-test.sh

frankenphp-size: ## Report image and uncompressed layer sizes
	docker image inspect $(FRANKENPHP_DEV_IMAGE) $(FRANKENPHP_RUNTIME_IMAGE) --format '{{.RepoTags}} {{.Size}} bytes'
	docker history $(FRANKENPHP_RUNTIME_IMAGE)

FRANKENPHP_REGISTRY_IMAGE ?= ghcr.io/frankverhoeven/php-8.5-frankenphp
RUNTIME_VERSION ?=
.PHONY: frankenphp-publish
frankenphp-publish: ## Publish tested native images as a multi-architecture runtime
	test -n "$(RUNTIME_VERSION)"
	docker tag containers-frankenphp:runtime-amd64 $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime-amd64
	docker push $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime-amd64
	docker tag containers-frankenphp:runtime $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime-arm64
	docker push $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime-arm64
	docker buildx imagetools create -t $(FRANKENPHP_REGISTRY_IMAGE):runtime -t $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime-amd64 $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime-arm64
	docker buildx imagetools inspect $(FRANKENPHP_REGISTRY_IMAGE):$(RUNTIME_VERSION)-runtime
