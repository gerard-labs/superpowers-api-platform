# Quality checks (reference)

## 1. PHP-CS-Fixer

```bash
composer require --dev friendsofphp/php-cs-fixer
```

```php
// .php-cs-fixer.dist.php
<?php

use PhpCsFixer\Config;
use PhpCsFixer\Finder;

$finder = Finder::create()
    ->in(__DIR__ . '/src')
    ->in(__DIR__ . '/tests');

return (new Config())
    ->setRiskyAllowed(true)
    ->setRules([
        '@Symfony'         => true,
        '@Symfony:risky'   => true,
        '@PER-CS2.0'       => true,
        '@PER-CS2.0:risky' => true,
        'declare_strict_types' => true,
        'phpdoc_align'         => false,
        'concat_space'         => ['spacing' => 'one'],
    ])
    ->setFinder($finder);
```

Run:

```bash
./vendor/bin/php-cs-fixer fix --diff
./vendor/bin/php-cs-fixer fix --dry-run --diff   # CI
```

---

## 2. PHPStan

```bash
composer require --dev phpstan/phpstan phpstan/extension-installer
composer require --dev phpstan/phpstan-symfony phpstan/phpstan-doctrine phpstan/phpstan-phpunit
```

```yaml
# phpstan.dist.neon
parameters:
    level: 9
    paths:
        - src
        - tests
    gerard:
        container_xml_path: var/cache/dev/App_KernelDevDebugContainer.xml
        constant_hassers: false
    doctrine:
        objectManagerLoader: tests/object-manager.php
    excludePaths:
        - src/DataFixtures
```

Run:

```bash
./vendor/bin/phpstan analyse
./vendor/bin/phpstan analyse --level=max     # progressive tightening
```

### Custom rules (project-specific)

Project-level rules can encode architectural decisions:

- Forbid `EntityManager` injection inside a State Provider.
- Force Command DTOs to be `final readonly`.
- Forbid a `#[ApiResource]` directly on a Doctrine `#[ORM\Entity]` (force the Resource ≠ Entity split).

A failing rule makes the CI red — the ADR becomes self-enforcing.

---

## 3. Psalm (optional)

If a project standardized on Psalm before PHPStan, both can coexist for a transition period. Choose one for new code; both is rarely worth the maintenance cost.

```bash
composer require --dev vimeo/psalm
./vendor/bin/psalm --show-info=false
```

---

## 4. PHPUnit + coverage

```xml
<!-- phpunit.xml.dist -->
<phpunit
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
    bootstrap="vendor/autoload.php"
    colors="true">

    <php>
        <ini name="memory_limit" value="-1"/>
        <env name="APP_ENV" value="test" force="true"/>
    </php>

    <testsuites>
        <testsuite name="Project Test Suite">
            <directory>tests</directory>
        </testsuite>
    </testsuites>

    <source>
        <include>
            <directory>src</directory>
        </include>
        <exclude>
            <directory>src/DataFixtures</directory>
            <directory>src/Migrations</directory>
        </exclude>
    </source>

    <extensions>
        <bootstrap class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
    </extensions>
</phpunit>
```

Run with coverage:

```bash
./vendor/bin/phpunit --coverage-clover coverage.xml --coverage-text
./vendor/bin/paratest -p8 --coverage-clover coverage.xml
```

### Coverage threshold enforcement

Use `coverage-check` or write a small script that parses `coverage.xml` and fails when the line coverage drops below the threshold (typically 100% on the domain layer, 80%+ elsewhere).

---

## 5. Infection (mutation testing)

Coverage proves a line ran ; **mutation testing proves an assertion would have caught a regression**. Infection rewrites the code (small, behavior-changing edits — flip `<` to `<=`, drop a `return`, swap `&&` for `||`) and reruns the suite. Each surviving mutant = a hole in the assertions.

```bash
composer require --dev infection/infection
./vendor/bin/infection --threads=4 --min-msi=80 --min-covered-msi=85
```

- `--min-msi=80` → ≥ 80 % of all generated mutants must be killed by the suite (across the configured `source` paths). CI fails otherwise.
- `--min-covered-msi=85` → on the *covered* code (the lines PHPUnit actually exercised), ≥ 85 % of mutants must die. Catches tautological tests that bump coverage without asserting anything.

### `infection.json5`

```json5
{
    "$schema": "vendor/infection/infection/resources/schema.json",
    "source": {
        "directories": [
            "src/Domain",
            "src/Application"
        ],
        "excludes": [
            "DataFixtures",
            "Migrations"
        ]
    },
    "timeout": 10,
    "logs": {
        "text":    "var/infection/infection.log",
        "html":    "var/infection/infection.html",
        "summary": "var/infection/summary.log",
        "json":    "var/infection/infection.json",
        "github":  true
    },
    "mutators": {
        "@default": true,
        "global-ignoreSourceCodeByRegex": [
            "Assert::.*"
        ]
    },
    "phpUnit": {
        "configDir": "."
    }
}
```

The `source` block targets only the layers where mutation testing pays off — domain, application, voters, processors. Mutating infrastructure or migrations produces noise (false survivors on plumbing) and explodes CI time.

### Run modes

```bash
# Full run (CI gate)
./vendor/bin/infection --threads=4 --min-msi=80 --min-covered-msi=85

# Per-target run on a critical class
./vendor/bin/infection --filter=src/Catalog/Domain/Money.php

# Mutate only the diff against main (PR-fast)
./vendor/bin/infection --threads=4 --git-diff-filter=AM --git-diff-base=origin/main

# Same with stricter MSI on the touched code only
./vendor/bin/infection --threads=4 --git-diff-filter=AM --git-diff-base=origin/main \
    --min-msi=90 --min-covered-msi=95
```

The `--git-diff-*` flags let CI keep the full-suite MSI gate at 80 / 85 while raising the bar to 90 / 95 on the lines changed in the PR — same pattern as a coverage *patch* threshold.

### Critical packages — MSI ≥ 80 / covered-MSI ≥ 85

Mandatory on :

- value objects with invariants (`Email`, `Money`, `Iban`, …),
- aggregates / entities with business rules,
- command handlers, query handlers,
- API Platform State Processors that mutate state,
- voters (decisions on permissions),
- finance / rights / PII / pricing code.

Infrastructure adapters, fixtures, migrations and pure DTOs (no behavior) are excluded — Infection on them produces noisy survivors without raising actual quality.

### Surviving mutants — triage rules

A surviving mutant means **one of three things**, in priority order :

1. **Missing assertion** — the test calls the code but doesn't assert the mutated property. Add the assertion.
2. **Tautological test** — `assertSame($x, $x)`, mock returns mirrored back. Rewrite the test against observable behavior.
3. **Equivalent mutant** — the mutation produced semantically identical code (rare). Document with `// @infection-ignore-all` + a comment explaining why ; never silence without explanation.

Never raise a "kill via try/catch" — that turns a real escape into a green light.

---

## 6. ParaTest

```bash
composer require --dev brianium/paratest
./vendor/bin/paratest -p8                # 8 parallel processes
./vendor/bin/paratest -p auto             # auto-detect CPU count
```

Essential once the suite exceeds ~30 seconds.

---

## 7. `composer audit` + `symfony check:security`

```bash
composer audit              # CVE check across composer.lock
symfony check:security      # FriendsOfPHP advisories DB
```

### CI integration (GitLab CI example)

```yaml
security-check:
    image: composer:2
    script:
        - composer install
        - composer audit
        - symfony check:security
    only:
        - merge_requests
        - main
```

The pipeline must fail on any critical CVE.

---

## 8. Production builds

**Never `composer update` in production.** Always:

```bash
composer install --no-dev --optimize-autoloader
```

- `--no-dev` excludes test / dev tools — reduces attack surface.
- `--optimize-autoloader` builds the optimized classmap — perf boot.
- The install respects `composer.lock` — reproducible across environments.

---

## 9. Renovate (or Dependabot)

Automate the dependency-update PR flow. Renovate config:

```json
// renovate.json
{
  "extends": ["config:base"],
  "packageRules": [
    { "matchUpdateTypes": ["patch"], "automerge": true },
    { "matchUpdateTypes": ["minor", "major"], "automerge": false }
  ],
  "vulnerabilityAlerts": { "labels": ["security"], "automerge": false }
}
```

- Patch updates auto-merge after the CI is green.
- Minor / major updates require human review.

---

## 10. CI workflow (GitHub Actions)

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          coverage: pcov
          tools: composer:v2

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: PHP-CS-Fixer
        run: ./vendor/bin/php-cs-fixer fix --dry-run --diff

      - name: PHPStan
        run: ./vendor/bin/phpstan analyse

      - name: Tests with coverage
        run: ./vendor/bin/paratest -p auto --coverage-clover coverage.xml --coverage-xml=var/coverage/coverage-xml --log-junit=var/coverage/junit.xml

      - name: Coverage threshold
        run: ./vendor/bin/coverage-check coverage.xml 90

      - name: Mutation testing (Infection)
        run: ./vendor/bin/infection --threads=4 --min-msi=80 --min-covered-msi=85 --coverage=var/coverage --skip-initial-tests --logger-github

      - name: Security audit
        run: composer audit
```

Two perf notes on the Infection step :

- `--coverage=var/coverage --skip-initial-tests` reuses the coverage already produced by the PHPUnit step ; Infection skips the initial run that would otherwise double the test cost.
- `--logger-github` (also set in `infection.json5`) annotates surviving mutants directly on the PR diff.

---

## 11. Mandatory CI rules

- **Unit-test coverage 100 % on domain classes** (entities, value objects, domain services, command handlers).
- **Functional tests mandatory on every API endpoint.** No new route without an `ApiTestCase` (cf. `gerard:api-platform-tests`).
- **PHPStan level ≥ 7** (push to 9 / max as the codebase matures).
- **PHP-CS-Fixer dry-run** must pass.
- **Infection MSI ≥ 80 % / covered-MSI ≥ 85 %** on configured `source` (domain + application). PR-level diff target : 90 / 95.
- **`composer audit`** must pass.
- **No `--no-verify`** allowed on commits.

---

## 12. Related skills

- `gerard:tdd-with-phpunit` — RED-GREEN-REFACTOR alignment.
- `gerard:tdd-with-pest` — alternative to PHPUnit.
- `gerard:functional-tests` — WebTestCase patterns.
- `gerard:api-platform-tests` — `ApiTestCase`, DAMA, Foundry, ParaTest.
- `gerard:ports-and-adapters` — Deptrac for architectural boundary checks (companion to PHPStan rules).
