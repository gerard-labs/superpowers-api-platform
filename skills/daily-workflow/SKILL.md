---

name: daily-workflow
allowed-tools:
  - Read
  - Glob
  - Grep
description: Day-to-day patterns for Symfony development — `bin/console debug:router` / `debug:container` / `debug:autowiring`, `bin/console doctrine:schema:validate`, `make:entity` / `make:controller` / `make:state-provider` scaffolds, profiler in dev (web debug toolbar), log inspection (`var/log/*.log`), session hook output as health check. Trigger on "where's this route defined", "why is this service not autowired", or "debug a 500 error".
---

# Daily Workflow (Symfony)

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
