---

name: strategy-pattern
allowed-tools:
  - Read
  - Glob
  - Grep
description: Implement the Strategy pattern via Symfony tagged services — `#[AutoconfigureTag('app.payment_processor')]` on each impl, inject the tagged iterator with `#[TaggedIterator('app.payment_processor', defaultIndexMethod: 'getName')]` or `#[TaggedLocator]` for keyed access, runtime selection by enum/string key. Useful for payment gateways, content type renderers, file format handlers, voter chains. Trigger on "select algorithm at runtime", "register N implementations of the same interface", or "extensible plugin-like system".
---

# Strategy Pattern (Symfony)

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
