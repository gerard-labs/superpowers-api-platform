SHELL=/bin/bash

.DEFAULT_GOAL := help
.PHONY: help console composer tests ci

help:
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "%-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

console: ##                     Symfony console (host PHP)
	php bin/console $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
	@:

composer: ##                    Composer wrapper
	composer $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
	@:

tests: ##                       Run PHPUnit
	./vendor/bin/phpunit

ci: ##                          Full CI
	$(MAKE) tests

%:
	@:
