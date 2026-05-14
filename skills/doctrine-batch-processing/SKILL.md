---

name: doctrine-batch-processing
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Process large-volume Doctrine datasets (million-row imports, mass updates, ETL) without memory blowup. Use `toIterable()` + `EntityManager::clear()` per batch, partial hydration with DQL projection (`NEW App\Dto\X(...)`), `HINT_READ_ONLY` when entities aren't mutated, `MEMORY_PEAK_USAGE` tracking. Trigger on "iterate over all entities", "import N rows", "mass update", "fix memory limit exceeded", or "OOM on Doctrine query".
---

# Doctrine Batch Processing (Symfony)

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
