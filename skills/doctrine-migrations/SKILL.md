---
name: doctrine-migrations
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Manage Doctrine schema evolution — `doctrine:migrations:diff` to generate from entity diff, `doctrine:migrations:migrate` to apply, custom up()/down() for data migrations, zero-downtime expand/contract patterns (add nullable column → backfill → set NOT NULL → drop), separate console commands for heavy data migrations, naming conventions per Symfony. Trigger when adding a column, renaming, splitting a table, or planning a UUID v7 retrofit.
---

# Doctrine Migrations (Symfony)

## Use when
- Designing entity relations or schema evolution.
- Improving Doctrine correctness/performance.

## Default workflow
1. Model ownership/cardinality and transactional boundaries.
2. Apply mapping/schema changes with migration safety.
2. Tune fetch/query behavior for hot paths.
2. Verify lifecycle behavior with targeted tests.

## Guardrails
- Keep owning/inverse sides coherent.
- Avoid destructive migration jumps in one release.
- Eliminate accidental N+1 and over-fetching.

## Progressive disclosure
- Use this file for execution posture and risk controls.
- Open references when deep implementation details are needed.

## Output contract
- Entity/migration changes.
- Integrity and performance decisions.
- Validation outcomes and rollback notes.

## References
- `reference.md`
- `docs/complexity-tiers.md`
