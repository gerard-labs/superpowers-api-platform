---
name: quality-checks
description: Configure and run the Symfony / API Platform 4.3 quality stack — PHP-CS-Fixer (`@Symfony` + `@PER-CS` rulesets), PHPStan level 9+ (with `phpstan-symfony` and `phpstan-doctrine` extensions), Psalm if needed, `composer audit` + Renovate for dependency CVEs, `composer install --no-dev --optimize-autoloader` for production builds, PHPUnit `--coverage-clover` with a CI-blocking minimum threshold (100% on the domain), ParaTest for parallel runs, Infection mutation testing with `--min-msi=80 --min-covered-msi=85` on critical packages, and CI patterns that fail on regressions. Trigger on "lint", "static analysis", "quality gates", "CI configuration", "composer audit", "production deploy", "coverage threshold", "mutation testing", "Infection", or "MSI".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Quality checks (Symfony / API Platform 4.3)

## Use when
- Bootstrapping the quality stack of a new project.
- Tightening static analysis (raising PHPStan level, enabling custom rules).
- Setting up CI quality gates that fail on regressions.
- Auditing dependencies for CVEs before deploy.

## Default workflow
1. PHP-CS-Fixer: install + `@Symfony` + `@PER-CS` rulesets + project-specific overrides.
2. PHPStan: install + `phpstan-symfony` + `phpstan-doctrine` + raise level progressively (5 → 7 → 9 → max).
3. PHPUnit: enable `--coverage-clover` and enforce a minimum on the domain layer.
4. ParaTest: `./vendor/bin/paratest -p8` for parallel CI runs.
5. Infection: `./vendor/bin/infection --threads=4 --min-msi=80 --min-covered-msi=85` — mutation testing on critical packages (domain, voters, processors, finance/rights/PII).
6. `composer audit` + `symfony check:security` on every PR.
7. Production builds: `composer install --no-dev --optimize-autoloader` — never `composer update`.
8. Renovate for automated dependency updates.

## Guardrails
- **CI fails on PHPStan regression.** No `// @phpstan-ignore` without a comment + ticket.
- **CI fails on coverage drop.** Minimum threshold enforced.
- **CI fails on MSI regression.** Minimum `--min-msi=80` and `--min-covered-msi=85` on critical packages. A green coverage with surviving mutants signals tautological tests — CI must reject it.
- **`composer audit` runs on every PR.** No CVE merged into main.
- **No `composer update` in CI / prod.** Always `composer install`.
- **No `--no-verify`** on commits / pushes — hooks exist for a reason.

## Progressive disclosure
- `SKILL.md` covers posture and tools.
- `reference.md` carries the full configs (PHP-CS-Fixer `.php-cs-fixer.dist.php`, `phpstan.dist.neon` with extensions, PHPUnit `phpunit.xml.dist`, GitHub Actions / GitLab CI templates, Renovate config).

## Output contract
- `.php-cs-fixer.dist.php`, `phpstan.dist.neon`, `phpunit.xml.dist`, `infection.json5` present and aligned.
- CI workflow that runs PHPStan + tests + coverage threshold + Infection (MSI ≥ 80, covered-MSI ≥ 85) + audit.
- Production deploy script using `composer install --no-dev --optimize-autoloader`.
- Renovate config (or equivalent) in place.

## References
- `reference.md`
