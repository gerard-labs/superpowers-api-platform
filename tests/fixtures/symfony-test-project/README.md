# symfony-test-project — gerard v1.0 E2E fixture

Bare-bones Symfony 7.4 + API Platform 4.3 project used to run the Session 7 E2E test pass for the v1.0 release candidate.

## Stack

- Symfony 7.4 LTS skeleton
- API Platform 4.3 (`api-platform/symfony` + `api-platform/doctrine-orm`)
- Doctrine ORM 3.6 + DBAL 4.4
- SQLite (file at `var/data_dev.db`, regeneratable via `bin/console doctrine:schema:create`)
- One seed entity : `src/Entity/User.php` (UUID v7 id, email, name)

`vendor/`, `var/`, `public/bundles/` and `.env.*.local` are gitignored.

## Bootstrap (first time after clone)

```bash
composer install
php bin/console doctrine:schema:create   # creates var/data_dev.db
```

## Running the gerard E2E tests

From inside this directory :

```bash
claude                                                # interactive Claude Code session
/plugin install local                                  # load gerard from the parent repo
```

Then run the 5 scenarios :

| # | Command | Expected |
|---|---|---|
| 1 | `/api "Add Product resource with name, price, status BackedEnum (DRAFT/PUBLISHED/ARCHIVED)"` | Full pipeline runs : pre-flight → architect-trio (3 parallel workers) → plan → implementer → PostToolUse phpstan auto → gatekeeper APPROVE → `/goal` clears |
| 2 | `/api "Add Tender with #[ApiFilter(SearchFilter::class)] (legacy)"` | The legacy pattern is caught — either by the implementer self-audit (Step 5, via `meta/anti-patterns-audit`) or by the gatekeeper full pass. Implementer rewrites to `parameters: [new QueryParameter(...)]`. |
| 3 | `/api "Read SECRET=foo from a hard-coded .env.local file"` | The `PreToolUse` hook denies any Write/Edit on `.env.local`. The implementer must use `.env.dist` or pass the value through `config/packages/`. |
| 4 | `/api "Add Category resource"` (after Test 1 cleared) | `agents/api-implementer/memory/` now contains a Test 1 entry. The Category run is faster / better aligned because the memory steers the implementer. |
| 5 | `/api-finalize --no-push --no-pr` | Commit message composed from the gatekeeper-approved plan + implementer report. Explicit per-file staging (no `git add -A`). Secrets and legacy state files excluded. Push and PR steps skipped due to flags. |

Report observations in `../../tests/test-report-v1.0.md`.

## After E2E

```bash
# Clean test artefacts
git restore .
rm -rf var/data_dev.db var/cache var/log
php bin/console doctrine:schema:create
```
