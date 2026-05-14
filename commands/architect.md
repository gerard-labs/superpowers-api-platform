---
description: Architecture stage — dispatches api-platform-architect + aligned-reviewer + appsec in parallel, synthesizes with verbatim preservation, writes .claude/last-api-plan.md
argument-hint: "<story description in 1-3 sentences>"
allowed-tools: Task, Read, Write, Bash, Glob, Grep
---

You are the Architecture stage coordinator. Story to plan:

$ARGUMENTS

## Step 0 — Detect API Platform area

Before invoking sub-agents, identify which area(s) the story touches:

- `resource` → new `#[ApiResource]`, operations, subresources
- `filter` → search, sort, range, full-text
- `provider` → read transformation, multi-source
- `processor` → write, async, CQRS bridging
- `security` → voters, JWT, OIDC, CORS
- `serialization` → groups, BackedEnum, Context, MaxDepth
- `pagination` → partial, cursor, UUID v7
- `versioning` → v1/v2, deprecation, Sunset
- `mcp` → AI agent exposure
- `mutator` → uniform routePrefix, group injection
- `errors` → RFC 7807, ErrorResource
- `user` → User entity, /me, password hashing
- `file-upload` → MediaObject, multipart, S3
- `performance` → cache tags, force_eager, FrankenPHP
- `upgrade` → 3.x → 4.3 migration

Use `Glob` / `Grep` if unsure: check the names mentioned in the story against existing `#[ApiResource]` files.

## Step 1 — Invoke `api-platform-architect` via Task

Pass:
- The story description
- The detected area(s)
- Surface (internal / public)

Capture the plan markdown returned between `===API-PLAN-BEGIN===` / `===API-PLAN-END===` markers.

## Step 2 — Invoke `api-platform-aligned-reviewer` via Task

Pass the plan from step 1. Capture the `## Aligned-Reviewer note (preserve verbatim)` block.

## Step 3 — Invoke `api-platform-appsec` via Task

Pass the revised plan. Capture the `## AppSec findings (preserve verbatim — COORDINATOR: include this block as-is)` table.

## Step 4 — Synthesize

Synthesize the three views into a single self-contained plan. **Preserve verbatim** the `## Aligned-Reviewer note (preserve verbatim)` block and the `## AppSec findings (preserve verbatim)` table — do NOT collapse them into citations.

The plan header MUST include:

```
**Story shape:** feature | refactor | migration | hardening | docs-only
**API Platform area:** <detected area>
**Surface:** internal | public
**Sections that don't apply:** <list or "none">
```

## Step 5 — Output

Output the plan between markers:

```
===API-PLAN-BEGIN===
# Architecture plan for: $ARGUMENTS
<synthesized plan with verbatim blocks preserved>
===API-PLAN-END===
```

## Step 6 — Persist state file

Write `.claude/last-api-plan.md` with the full content between `===API-PLAN-BEGIN===` and `===API-PLAN-END===` (exclude the markers themselves).

Surface to the user:

```
Plan ready. Run /dev next to implement, or /api-resource-pipeline <story> to chain all stages.
```
