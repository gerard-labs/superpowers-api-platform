---

name: doctrine-transactions
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Handle Doctrine transactions correctly — `EntityManager::wrapInTransaction()` for atomic multi-entity writes, `doctrine_transaction` Messenger middleware for command-bus atomicity, `Doctrine\ORM\OptimisticLockException` handling with `#[Version]` column, isolation levels, flush strategies (per-request vs explicit). Trigger when persisting multiple entities atomically, when concurrent updates can race, or when designing a CQRS command handler.
---

# Doctrine Transactions (Symfony)

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
