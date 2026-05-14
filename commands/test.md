---
description: Test stage — symfony-tdd-coach reads plan + dev report, validates AC × test mapping, kills Infection mutants in-session, emits API-TEST report
allowed-tools: Task, Read, Write, Edit, Bash, Glob, Grep
---

You are the Test stage coordinator. Inputs:

- `.claude/last-api-plan.md` — the architecture plan (with test matrix)
- `.claude/last-api-dev-report.md` — the dev implementation report (lists classes touched)

## Step 1 — Read state files

```
Read .claude/last-api-plan.md          # extract test matrix
Read .claude/last-api-dev-report.md    # identify critical classes touched
```

## Step 2 — Invoke `symfony-tdd-coach` via Task

The tdd-coach MUST follow the gold-standard workflow:

1. Read state files first (architects test matrix is the contract)
2. Run `./vendor/bin/phpunit --filter=Api` → iterate until green
3. Run `./vendor/bin/infection --filter=<critical-classes>` → identify escaped mutants on critical paths
4. For each killable escapee: Write the killing test (force the invariant), re-run mutation
5. Emit checklist `AC → test path → status` covering THE WHOLE matrix
6. Anti-tautology audit on new tests
7. Emit report between `===API-TEST-BEGIN===` / `===API-TEST-END===`

**No "recommend follow-up" on critical paths** — kill or reject (the dev report is bounced back).

## Step 3 — Persist state file

Write `.claude/last-api-test-report.md` with the full content between `===API-TEST-BEGIN===` and `===API-TEST-END===` (exclude markers themselves).

Surface to the user:

```
Tests done. Run /review next.
```
