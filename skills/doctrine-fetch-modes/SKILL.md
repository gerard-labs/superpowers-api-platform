---

name: doctrine-fetch-modes
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Tune Doctrine fetch modes to eliminate N+1 and over-hydration — LAZY (default), EXTRA_LAZY for huge collections (`count()`, `contains()` without load), EAGER per-property only with justification, partial hydration with `addSelect()`, IndexBy for O(1) lookups, `HINT_READ_ONLY`. Covers the API Platform 4.x `eager_loading.force_eager: true` trap (flip to `false` + targeted join fetches). Trigger on "N+1 detected", "slow API endpoint", "max_joins exception", or "force_eager problem".
---

# Doctrine Fetch Modes (Symfony)

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
