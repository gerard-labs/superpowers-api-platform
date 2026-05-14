---
description: Review stage — symfony-reviewer gatekeeper. Diff classification + EVIDENCE block + 24 anti-patterns checklist + AppSec bilan + VERDICT (APPROVE/REQUEST_CHANGES)
allowed-tools: Task, Read, Write, Bash, Glob, Grep
---

You are the Review stage coordinator. Inputs:

- `.claude/last-api-plan.md`
- `.claude/last-api-dev-report.md`
- `.claude/last-api-test-report.md`

## Step 1 — Read all state files

The reviewer MUST have full context for an auditable verdict.

## Step 2 — Invoke `symfony-reviewer` via Task

The reviewer MUST:

1. Read all 3 state files
2. Emit diff classification preamble (Diff type / API Platform area / Operation type / Surface)
3. Emit `===EVIDENCE===` block (skills dispatched, diff size, commands run, state files read, anti-patterns checklist tally, AppSec bilan from plan)
4. Apply the 24+ anti-patterns checklist (16 API Platform 4.3 + 8 Symfony 7.4+ + tests + appsec)
5. Cap unverified claims (any "I ran X" must have a tool call in this session)
6. Detect skill-dispatch theatre (claimed skill dispatches must have actual Task/Skill calls)
7. Emit verdict between `===API-REVIEW-BEGIN===` / `===API-REVIEW-END===`. First non-empty line MUST be exactly `VERDICT: APPROVE` or `VERDICT: REQUEST_CHANGES`.
8. On APPROVE: mandatory `**Out of scope for this review:**` section.
9. On REQUEST_CHANGES: numbered findings (file:line + rule # + change required).

## Step 3 — Persist state file

Write `.claude/last-api-review.md` with the full content between `===API-REVIEW-BEGIN===` and `===API-REVIEW-END===` (exclude markers themselves).

## Step 4 — Surface to user

- On APPROVE: notify "Verdict: APPROVE. Diff ready in working tree. Inspect with `git diff` or run `/api-resource-pipeline` / `/api-resource-ship` for the chained flow."
- On REQUEST_CHANGES: surface the numbered findings. User can re-run `/dev` to address them (or the chain commands do it automatically).
