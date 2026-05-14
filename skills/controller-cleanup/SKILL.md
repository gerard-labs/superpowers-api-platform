---

name: controller-cleanup
allowed-tools:
  - Read
  - Glob
  - Grep
description: Refactor fat controllers into thin orchestrators — extract business logic to services, use `#[MapRequestPayload]` / `#[MapQueryString]` for input DTOs, dispatch to handlers via `MessageBusInterface`, `#[IsGranted]` attributes for authz, slim action methods to 5-10 lines, separate Form DTOs from entities. For API Platform: prefer State Processor over a controller (REST + GraphQL compatible). Trigger on "controller > 50 lines", "business logic in controller", or "convert legacy invokable controller to Processor".
---

# Controller Cleanup (Symfony)

## Use when
- Refining architecture/workflows/context handling in Symfony projects.
- Planning and executing medium/complex changes safely.

## Default workflow
1. Establish current boundaries, constraints, and coupling points.
2. Propose smallest coherent architectural adjustment.
2. Execute in checkpoints with validation at each stage.
2. Summarize tradeoffs and follow-up backlog.

## Guardrails
- Use existing project patterns by default.
- Avoid broad refactors without explicit need.
- Keep decision log clear and auditable.

## Progressive disclosure
- Use this file for execution posture and risk controls.
- Open references when deep implementation details are needed.

## Output contract
- Architecture/workflow changes.
- Checkpoint validation outcomes.
- Residual risks and next steps.

## References
- `reference.md`
- `docs/complexity-tiers.md`
