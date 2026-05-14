# Doctrine Migrations (reference)

> Companion to `SKILL.md`. Symfony 7.4+ / Doctrine ORM / DoctrineMigrationsBundle.

## 1. Install

```bash
composer require doctrine/doctrine-migrations-bundle
```

Symfony Flex auto-creates `config/packages/doctrine_migrations.yaml` :

```yaml
doctrine_migrations:
    migrations_paths:
        'DoctrineMigrations': '%kernel.project_dir%/migrations'
    enable_profiler: false
```

## 2. Diff-driven workflow (most common)

You modified an entity; Doctrine computes the migration for you.

```bash
# Inspect what changed
php bin/console doctrine:schema:validate

# Generate the migration from the diff
php bin/console doctrine:migrations:diff

# Inspect — never apply blindly
$EDITOR migrations/Version<timestamp>.php

# Apply
php bin/console doctrine:migrations:migrate --no-interaction

# Dry-run (recommended before prod)
php bin/console doctrine:migrations:migrate --dry-run
```

The generated migration has `up()` + `down()`. Inspect them — Doctrine sometimes generates surprising operations (e.g. drop+create instead of alter on enum changes).

## 3. Custom migration (data migration)

Use a custom `up()` when you need to backfill data, not just shape change:

```php
<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260511120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Backfill product slugs from name (one-time data migration).';
    }

    public function up(Schema $schema): void
    {
        // Schema change first (if any)
        $this->addSql('ALTER TABLE product ADD COLUMN slug VARCHAR(255) DEFAULT NULL');

        // Data backfill in chunks (avoid OOM on huge tables)
        $this->addSql(<<<SQL
            UPDATE product
            SET slug = LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '-', 'g'))
            WHERE slug IS NULL
        SQL);

        // Constraint AFTER data is filled
        $this->addSql('ALTER TABLE product ALTER COLUMN slug SET NOT NULL');
        $this->addSql('CREATE UNIQUE INDEX uniq_product_slug ON product (slug)');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP INDEX uniq_product_slug');
        $this->addSql('ALTER TABLE product DROP COLUMN slug');
    }
}
```

For **huge data migrations** (> 100k rows), prefer a dedicated console command outside the migration file — migrations are meant to run inside a single transaction.

## 4. Zero-downtime expand/contract pattern

When a column rename or breaking change happens on a live system, **don't** rename in a single migration. Split into 3 releases :

### Release 1 — Expand

```php
// Add new column nullable; keep the old one
$this->addSql('ALTER TABLE user ADD COLUMN email_address VARCHAR(255) DEFAULT NULL');
$this->addSql('CREATE INDEX idx_user_email_address ON user (email_address)');
```

Application code writes to BOTH old and new columns. Reads from old.

### Release 2 — Backfill + switch reads

Console command (not migration) to backfill :

```bash
php bin/console app:user:backfill-email-address --batch-size=1000
```

Then a tiny migration to switch reads :

```php
public function up(Schema $schema): void
{
    // Code change has flipped reads to email_address. Just set NOT NULL.
    $this->addSql('ALTER TABLE user ALTER COLUMN email_address SET NOT NULL');
}
```

### Release 3 — Contract

```php
public function up(Schema $schema): void
{
    $this->addSql('DROP INDEX idx_user_email');
    $this->addSql('ALTER TABLE user DROP COLUMN email');
}
```

The system stayed up the whole time.

## 5. Anti-patterns

- ❌ Renaming a column in a single migration on a live system → race window where old code writes to the renamed column → crash
- ❌ `doctrine:schema:update --force` in production → bypasses migrations history → drift
- ❌ Editing a migration AFTER it has been applied in any environment → re-running gives `MigrationException`
- ❌ Doctrine generates a destructive change (`DROP TABLE`) by mistake — always inspect the generated migration
- ❌ Heavy data backfill inside `up()` on a 50M-row table → transaction explodes → use a console command + chunked SQL
- ❌ Multiple unrelated changes in one migration → if rollback needed, you revert too much

## 6. Naming conventions

- File name : `Version<YYYYMMDDHHMMSS>.php` (auto-generated)
- `getDescription()` mandatory, one sentence ("Add slug column to product")
- Migration commit message : `feat(db): add product.slug column for SEO URLs`

## 7. Workflow per environment

| Environment | Strategy |
|---|---|
| Dev / local | `migrations:migrate --no-interaction` after every pull. Auto via post-merge git hook OK. |
| CI | `migrations:migrate` on a fresh test DB before tests. Use `--allow-no-migration` to tolerate empty migrations folder on fresh clones. |
| Staging | Same as prod (dry-run first, then apply). Reproducible. |
| Production | `--dry-run` first. Backup DB. Apply during low-traffic window. Monitor for slow migrations (locks). |

## 8. UUID v7 retrofit (common ask)

If existing tables use `INT AUTO_INCREMENT` and you want to migrate to UUID v7 (for the IRI-only rule in API Platform 4.3) :

```
Release 1 — Add UUID v7 column nullable, generate value on insert (trigger or app code)
Release 2 — Backfill existing rows via console command (chunked)
Release 3 — Add unique index on UUID column
Release 4 — Update foreign keys to use UUID (this is the heavy one)
Release 5 — Switch primary key to UUID, drop old INT
```

Plan all 5 releases at architecture time (use `gerard:api-platform-identifiers`).

## 9. Multi-database / multi-EntityManager

If your project has several Doctrine EntityManagers, configure paths per manager :

```yaml
doctrine_migrations:
    migrations_paths:
        'App\Migrations\Default': '%kernel.project_dir%/migrations/default'
        'App\Migrations\Audit':   '%kernel.project_dir%/migrations/audit'
```

Run per manager :

```bash
php bin/console doctrine:migrations:migrate --em=default
php bin/console doctrine:migrations:migrate --em=audit
```

## 10. Validation commands

```bash
# Verify schema is in sync with entities
php bin/console doctrine:schema:validate

# List migrations and their status
php bin/console doctrine:migrations:status
php bin/console doctrine:migrations:list

# Re-run a migration in dev
php bin/console doctrine:migrations:execute <version> --up
php bin/console doctrine:migrations:execute <version> --down
```

## 11. Related skills

- `gerard:doctrine-relations` — when adding a relation, generate the migration from it
- `gerard:doctrine-transactions` — atomic semantics inside a migration
- `gerard:doctrine-batch-processing` — for huge data backfills (use a console command, not the migration)
- `gerard:api-platform-identifiers` — UUID v7 / ULID retrofit planning
- `gerard:api-platform-upgrade` — for API Platform schema flips during a major upgrade
