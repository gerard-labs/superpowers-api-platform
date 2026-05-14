---
name: brainstorming
description: Pre-architecture brainstorming for an API Platform feature — when the story isn't yet stable enough to feed `/architect`. Explores requirements, identifies invariants, considers alternatives, surfaces unknowns, defines the smallest valuable slice. Output: a refined story description ready for `/architect <story>` or `/api-resource-pipeline <story>`. Use BEFORE the pipeline when the prompt is too vague.
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Brainstorming (pre-architecture)

## Use when
- A story is too vague to feed `/architect` directly
- You want to explore requirements + alternatives before committing to a plan
- Multiple framings of the same feature exist; you want to pick one
- The "smallest next step" is unclear

> **Position**: this skill is **upstream of the pipeline**. Output = refined story description suitable for `/architect <story>` or `/api-resource-pipeline <story>`. Once the brainstorm converges, exit and feed the pipeline.

## Default workflow
1. **Restate the story** in your own words. Get explicit agreement on the goal.
2. **Surface invariants** : what MUST be true at the end? (user-visible features + non-functional like perf, security, a11y).
3. **List alternatives** : 2-3 ways to deliver the invariants. Compare on complexity / risk / time.
4. **Pick the smallest valuable slice** : the smallest PR that surfaces the most risky hypothesis.
5. **Identify unknowns** : what would falsify the design? Where are the spikes needed?
6. **Refine the story description** — one paragraph, ready to feed `/architect`.

## Guardrails
- Stay upstream. Don't propose code, file paths, or skill dispatch — that's the architect's job.
- Time-box the brainstorm. If you can't refine the story in 10 prompts, the story is too big — split it.
- No premature pattern selection (CQRS vs simple service, DTO vs Object Mapper, etc.) — that's also the architect's decision.

## Output contract

- A refined story description (1 paragraph) usable as `$ARGUMENTS` of `/architect`.
- A short list of explicit invariants + non-invariants ("nice to have" excluded).
- A note on the smallest valuable slice.

## Progressive disclosure

- This file for the brainstorm flow
- `docs/complexity-tiers.md` for sizing the brainstorm output

## References
- `docs/complexity-tiers.md`
- `docs/symfony/pipeline-overview.md` — what happens after the brainstorm converges
