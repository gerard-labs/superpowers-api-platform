SHELL=/bin/bash

.DEFAULT_GOAL := help
.PHONY: help up down console composer tests ci quality migrations

help:
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "%-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ##                          Start services
	docker compose up -d

down: ##                        Stop services
	docker compose down

console: ##                     Symfony console (make console <cmd>)
	docker compose exec php bin/console $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
	@:

composer: ##                    Composer wrapper
	docker compose exec php composer $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
	@:

tests: ##                       Run PHPUnit
	docker compose exec php ./vendor/bin/phpunit

ci: ##                          Full CI pipeline
	$(MAKE) quality
	$(MAKE) tests

quality: ##                     Lint + PHPStan + CS-Fixer
	docker compose exec php ./vendor/bin/phpstan analyse

migrations: ##                  Run Doctrine migrations
	docker compose exec php bin/console doctrine:migrations:migrate --no-interaction

%:
	@:
