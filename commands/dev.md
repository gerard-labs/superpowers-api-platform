---
description: Dev stage — api-platform-implementer reads .claude/last-api-plan.md and implements (writes code, runs phpstan + phpunit + Infection on critical classes)
argument-hint: "(reads .claude/last-api-plan.md)"
allowed-tools: Task, Read, Write, Edit, Bash, Glob, Grep
---

You are the Dev stage coordinator. The architecture plan to implement is in `.claude/last-api-plan.md`.

## Step 1 — Read the plan

```
Read .claude/last-api-plan.md
```

Note the `**API Platform area:**` declared in the plan header. The implementer will use it to detect which `gerard:*` skills to invoke (and which `<project>:*` overrides to check via Glob).

## Step 2 — Read REQUEST_CHANGES feedback if any

If this is an iteration of a REQUEST_CHANGES loop:

```
Read .claude/last-api-review.md
```

Pass the reviewer's findings to the implementer so it can address them specifically.

## Step 3 — Invoke `api-platform-implementer` via Task

Pass:
- The plan (read at step 1)
- The reviewer feedback (if iteration)

The implementer MUST:
- Read state files first
- Detect API Platform area + project skill overrides
- Read relevant `gerard:api-platform-*` skills BEFORE editing
- Implement the change (resource + DTOs + provider/processor + filters + tests)
- Run `./vendor/bin/phpunit --filter=Api` until green
- Run `./vendor/bin/phpstan analyse`
- Run `./vendor/bin/infection --filter=<critical-classes>` on changed critical classes
- Apply AppSec mitigations from the plan
- Self-audit Y/N checklist
- Emit report between `===API-DEV-BEGIN===` / `===API-DEV-END===`

## Step 4 — Persist state file

Write `.claude/last-api-dev-report.md` with the full content between `===API-DEV-BEGIN===` and `===API-DEV-END===` (exclude markers themselves).

Surface to the user:

```
Dev done. Run /test next.
```
