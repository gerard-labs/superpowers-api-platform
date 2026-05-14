---

name: bootstrap-check
allowed-tools:
  - Read
  - Glob
  - Grep
description: Verify a Symfony project's bootstrap state before any work — `.env` / `.env.dist` parity, `config/bundles.php` enabled bundles, `config/services.yaml` recipe-default `App\` block with `exclude:`, `config/packages/api_platform.yaml` flags (`hydra_prefix`, `eager_loading.force_eager`, `use_symfony_listeners`), `composer.lock` presence, framework / API Platform versions detected by the session hook. Trigger on first session in a repo, when `make ci` fails with "missing X", or before kicking off `/api-resource-pipeline`.
---

# Bootstrap Check (Symfony)

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
