---
name: writing-plans
description: Create structured implementation plans for non-API-Platform features (Doctrine entity design, refactor cross-skill, infra changes, monorepo migrations). Outputs a step-by-step plan with explicit dependencies, AC, and validation commands. NOT used inside the API Platform pipeline (`/api-resource-pipeline` / `/api-resource-ship`) — that pipeline has its own `api-platform-architect` stage which produces the plan. Use for hors-pipeline plans.
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Writing plans (hors pipeline)

## Use when
- Designing a non-API-Platform feature (Doctrine entity, refactor, infra)
- Planning a multi-skill refactor (`/api-resource-pipeline` doesn't cover this)
- Planning a migration that touches multiple sub-projects (monorepo case)
- Pre-implementation design with explicit dependencies + AC

> **Not for**: API Platform features. Use `/api-resource-pipeline` or `/architect <story>` instead — the `api-platform-architect` agent produces the canonical 9-section plan including the test matrix and skill dispatch list.

## Default workflow
1. Establish current boundaries, constraints, coupling points.
2. List explicit dependencies (what skills / packages / migrations the plan touches).
3. Propose the smallest coherent step.
4. Define acceptance criteria + validation commands per step.
5. Summarize trade-offs and follow-up backlog.

## Guardrails
- Use existing project patterns by default.
- Avoid broad refactors without explicit need.
- Keep decision log clear and auditable.
- For API Platform-specific plans: redirect to `/architect` (canonical 9-section plan with verbatim Aligned-Reviewer + AppSec blocks).

## Progressive disclosure
- Use this file for posture + decision tree.
- Open `reference.md` for the deeper plan template.
- Open `docs/complexity-tiers.md` for sizing.

## Output contract
- Step-by-step plan (numbered, with dependencies)
- AC + validation per step
- Trade-offs documented
- Follow-up backlog

## References
- `reference.md`
- `docs/complexity-tiers.md`
- `docs/symfony/pipeline-overview.md` — for the API Platform pipeline alternative
