---

name: config-env-parameters
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Manage Symfony configuration layers — `.env` / `.env.local` / `.env.<env>` precedence, `parameters.yaml`, `services.yaml` (recipe-default `App\` + `exclude:` block), bound parameters via `bind:`, env-vars typed processors (`%env(int:X)%`, `%env(json:Y)%`, `%env(resolve:Z)%`), Symfony Vault for secrets, runtime vs build-time settings, `SYMFONY_TRUSTED_PROXIES` for reverse proxies. Trigger on "add env var", "secrets management", "services autowiring", or "reverse proxy in dev breaks HTTPS URLs".
---

# Config Env Parameters (Symfony)

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
