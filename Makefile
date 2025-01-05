ARGS = $(filter-out $@,$(MAKECMDGOALS))
MAKEFLAGS += --silent

.PHONY: build help

build: ## Build image from the provided Dockerfile
	docker build . -f ${ARGS}

help: ## List available commands
	@grep -E '^[a-zA-Z%_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

%:
	@:
