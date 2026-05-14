SHELL=/bin/bash

ENV_DIR := conf/
ENV_FILES := $(wildcard $(ENV_DIR).env*)
-include $(ENV_FILES)
export

STACK_ENV ?= local
DOCKER_DIR ?= docker
user ?= root

include Makefile-solution

.DEFAULT_GOAL := help
.PHONY: help up down ps logs config

help:
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "%-20s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Docker

up: ##                          Start services
	docker compose up -d

down: ##                        Stop services
	docker compose down

ps: ##                          List services
	docker compose ps

logs: ##                        Tail logs
	docker compose logs -f

config: ##                      Show compose config
	docker compose config

%:
	@:
