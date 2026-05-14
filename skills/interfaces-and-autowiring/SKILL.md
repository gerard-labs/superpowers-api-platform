---

name: interfaces-and-autowiring
allowed-tools:
  - Read
  - Glob
  - Grep
description: Master Symfony DI — interface autowiring (one impl per interface = automatic binding), `#[Autowire(service: 'X')]` for explicit override, `#[AutowireDecorated]` for decorators, `#[Target('name')]` for named-client routing (e.g. `HttpClientInterface` scoped clients), tagged services with `#[AsTaggedItem]` / `#[AutoconfigureTag]`, `#[AsAlias('id')]` for service aliases. Decorator pattern via `#[AsDecorator(decorates: 'id')]`. Trigger on "inject this", "decorate an API Platform processor", "multiple impls of same interface", or "named HTTP client".
---

# Interfaces And Autowiring (Symfony)

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
