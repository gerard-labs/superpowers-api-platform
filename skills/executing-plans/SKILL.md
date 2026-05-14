---
name: executing-plans
description: Execute a hors-pipeline implementation plan with checkpoints, TDD discipline, and continuous validation. Each plan step has explicit AC + validation commands; you run them, capture output, and proceed only on green. NOT used inside `/api-resource-pipeline` — the pipeline has its own dev/test/review stages. Use for manual execution of `gerard:writing-plans` outputs.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Executing plans (hors pipeline)

## Use when
- Executing a plan produced by `gerard:writing-plans` (or any hors-pipeline plan)
- Stepping through a multi-skill refactor with checkpoints
- Manual TDD on a non-API-Platform feature
- Migration that needs checkpointed validation between steps

> **Not for**: API Platform features in pipeline mode. Use `/api-resource-pipeline` or `/api-resource-ship` — those have their own dev/test/review stages with state files and REQUEST_CHANGES loop.

## Default workflow
1. Read the plan (from `gerard:writing-plans` or a markdown plan file).
2. For each step :
   - Re-read the step's AC + dependencies + validation commands.
   - Implement minimally to satisfy the AC.
   - Run the validation commands.
   - On red: fix in-session, re-run.
   - On green: checkpoint, move to next step.
3. After the last step : full quality gate (`/symfony-check` or equivalent).
4. Summarize what was shipped + follow-up backlog.

## Guardrails
- One step at a time. No batching that breaks the checkpoint discipline.
- No silent trim of plan steps — if a step doesn't make sense anymore, document why and update the plan.
- TDD when applicable: RED → GREEN → REFACTOR per step.
- For API Platform: redirect to the pipeline commands.

## Progressive disclosure
- This file for execution posture
- `reference.md` for deeper patterns
- `docs/complexity-tiers.md` for sizing

## Output contract
- Per-step execution trace (AC met / validation green / files touched)
- Final summary + follow-ups

## References
- `reference.md`
- `docs/complexity-tiers.md`
- `docs/symfony/pipeline-overview.md` — for the API Platform pipeline alternative
