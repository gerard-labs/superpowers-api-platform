---

name: effective-context
allowed-tools:
  - Read
  - Glob
  - Grep
description: Give Claude effective context for Symfony work — explicit Symfony / API Platform / PHP versions, stack profile (monolith vs monorepo, Doctrine vs Mongo, JWT vs OIDC), relevant files paths (`src/`, `templates/`, `config/`), surface (admin vs public vs MCP), constraints (Lighthouse target, multi-tenant, real-time). Anti-patterns: vague "make it better", missing version, wall of code with no question. Trigger when crafting the initial prompt for `/architect` or any non-trivial task.
---

# Effective Context (Symfony)

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
