---
description: Implement an API Platform 4.3 story end-to-end via the architect-trio → implementer → gatekeeper loop (native /goal driven).
argument-hint: "<story text> [--interactive] [--effort low|high|xhigh]"
allowed-tools: Bash, Read, Glob, Grep, Task, Monitor
---

# /api — Story-to-PR autopilot

Single entry point for "implement this API story". You orchestrate three v1.0 agents and let native `/goal` (Claude Code 2.1.139+) drive the loop until the gatekeeper approves.

Decisions verrouillées you must NOT relitigate (see `docs/v1.0-plan.md` section 1) :
- 3 agents (architect-trio, implementer, gatekeeper) — no other dispatch
- Full-auto by default. `--interactive` only when the user opts in.
- `/api-finalize` is a separate step; do NOT commit or push from here.
- Memory is per-agent (each agent reads/writes its own `memory/` dir).

---

## 1. Pre-flight (block on any failure)

Run these checks. If anything fails, STOP and tell the user explicitly before going further.

!git rev-parse --show-toplevel
!git status --porcelain
!git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED_HEAD"

Hard requirements:
- `git status --porcelain` must be empty (no uncommitted / untracked work). If not: STOP, ask the user to commit, stash, or clean before retrying.
- Must be inside a git repo. If `git rev-parse` failed: STOP.
- If on `main` / `master` / `develop`: ask the user for a branch name, then `git checkout -b <name>`. Derive a sensible default from the story (kebab-case, prefix `api/`).

If a `.claude/last-api-*.md` legacy file exists: ignore it. The v1.0 flow does not use those marker files — they are leftovers from v0.1 and will be deleted by Session 7.

---

## 2. Parse arguments

User input: `$ARGUMENTS`

Extract:
- `--interactive` flag → set `INTERACTIVE=true` (default `false`)
- `--effort low|high|xhigh` → set `EFFORT` (default `high`)
- Everything else → `STORY` (the natural-language story)

If `STORY` is empty: STOP and ask the user to supply a story.

---

## 3. Classify the story shape

Use keyword heuristics on `STORY` to pick a shape. This drives the `/goal` condition template below.

| Shape | Trigger keywords |
|---|---|
| `new-resource` | "add resource", "new entity", "new resource", "create X resource" |
| `new-operation` | "add Patch", "expose Delete", "new operation on" |
| `new-filter` | "filter", "search by", "sort by", "facet" |
| `new-state-flow` | "state processor", "state provider", "workflow" |
| `migration` | "migrate", "doctrine migration", "schema change" |
| `bugfix` | "fix", "bug", "regression", "crash" |
| `refactor` | "refactor", "extract", "rename", "split" |
| `security-hardening` | "harden", "auth", "JWT", "Voter", "CORS" |
| `generic` | (fallback) |

Announce the detected shape to the user in one line: `gerard: detected shape = <shape>, effort = <effort>, interactive = <bool>`.

---

## 4. Compose the /goal condition

Templates live in `skills/meta/goal-patterns/SKILL.md` (source of truth). Read that skill via `Skill gerard:goal-patterns`, pick the addendum matching the detected shape, and append it to the base condition. Substitute `<plural>` (from STORY) and `<branch>` (from current symbolic-ref).

The base 4 bullets (gatekeeper APPROVE + AppSec H1/H2 zero + tests green + hook-clean) are non-negotiable — every shape inherits them.

If the shape is `generic`, no addendum is appended; the base condition stands alone.

---

## 5. Dispatch the architecture stage

Use `Task` tool with `subagent_type=api-architect-trio`. The agent will:
- Read its own `agents/api-architect-trio/memory/` dir
- Classify the story (shape × API Platform area × surface)
- Spawn 3 background workers (design / aligned / appsec) in parallel via worktree isolation
- Synthesize the plan preserving the Aligned + AppSec blocks verbatim
- Return a Task output containing the plan markdown

Prompt for the architect-trio Task: include `STORY`, the detected shape, the chosen effort, and the composed `/goal` condition. Tell it to write the plan synchronously (no marker files, no `.claude/last-api-plan.md` — that pattern is dead).

---

## 6. Interactive checkpoint (only if `--interactive`)

If `INTERACTIVE=true`: print the plan to the user, ask explicitly:
> "Architect plan above. Approve to continue to implementer, or cancel?"

Wait for the user's reply. If they want changes, restart from step 5 with the feedback as additional context. Do NOT skip this if the flag is set.

If `INTERACTIVE=false`: proceed straight to step 7.

---

## 7. Launch native /goal loop (implementer ⇄ gatekeeper)

Issue the native `/goal` invocation with the composed condition. Inside the loop:

1. Dispatch `Task` with `subagent_type=api-implementer`. Input = architect's plan + STORY + effort + (if a previous gatekeeper review exists) its REQUEST_CHANGES feedback.
2. When implementer returns: dispatch `Task` with `subagent_type=gerard-gatekeeper`. Input = architect plan + implementer's report. **Fresh session, no shared context with implementer (adversarial)**.
3. Read the gatekeeper VERDICT (first line of its report):
   - `APPROVE` → goal evaluator should clear the goal on the next turn.
   - `REQUEST_CHANGES` → loop back to step 1 with the gatekeeper feedback appended to the implementer prompt.
4. Hard cap at 12 implementer-gatekeeper turns. If reached: surface the gatekeeper's last report and ask the user what to do.

The post-tool-use hook will already run regex + phpstan between turns. The gatekeeper handles the full 39-rule adversarial review.

---

## 8. After goal-clear

When `/goal` says condition met:
- Print a one-line completion banner: `gerard: goal cleared on <branch>. Run /api-finalize to commit + open PR.`
- Do NOT commit. Do NOT push. Do NOT open a PR. `/api-finalize` is the inspection point — separation is intentional (decision C in the plan).
- Remind the user that the stop hook should have emitted a desktop bell + notification.

---

## 9. On failure or escape hatch

If the user cancels mid-flow, or the loop hits the 12-turn cap, or any agent errors out:
- Leave the working tree as-is (do not revert).
- Print a summary of what was attempted + the last gatekeeper verdict.
- Tell the user how to resume (re-run `/api "<same story>" --interactive` for human-in-the-loop, or hand-edit and re-run).
