---
name: using-symfony-superpowers
description: Entry point and command map for the gerard plugin. Lists the 7 agents (3 architecture personas + implementer + tdd-coach + reviewer + doctrine-architect utility), the 7 pipeline commands (/architect, /dev, /test, /review, /api-resource-pipeline, /api-resource-ship, /self-audit-api), the 53 skills, the state-files protocol, and the authority order (CLAUDE.md > stage personas > project skills layer > plugin canon). Use to onboard a new project, choose between pipeline vs atomic skill invocation, or locate a specific doctrine.
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Using gerard plugin

## Use when
- Onboarding a project to the plugin
- Choosing between **pipeline** (chained stages, state files, REQUEST_CHANGES loop) and **atomic skill invocation** (single skill, no orchestration)
- Locating a specific skill / agent / command
- Setting up the project skills layer (`<project>:X` overrides)

## Two modes of operation

### A. Pipeline mode (recommended for non-trivial features)

Use one of:
- **`/api-resource-pipeline <story>`** — chains the 4 stages (architect → dev → test → review) with REQUEST_CHANGES loop (cap 3), **stops before commit** so you can inspect.
- **`/api-resource-ship <story>`** — same as pipeline but **commits + pushes + opens PR autonomously** with garde-fous (refuses dirty tree, explicit `git add`, skips secrets, no `--force`/`--no-verify`).

State files in `.claude/last-api-*.md` track stage handoffs (gitignored).

### B. Atomic mode (for quick edits or hors-pipeline)

Invoke a single skill or agent directly:
- `Skill({ skill: "gerard:api-platform-filters" })`
- `Task(subagent_type="api-platform-implementer", ...)`

Or use one of the legacy/utility commands:
- `/brainstorm` (pre-architecture brainstorming)
- `/write-plan`, `/execute-plan` (manual plan/execute hors pipeline)
- `/symfony-check` (quality gates)
- `/symfony-api-filters`, `/symfony-api-mcp`, etc. (skill-specific)

## Default workflow

1. Read this skill (`gerard:using-symfony-superpowers`) — entry point.
2. Decide pipeline vs atomic (see below).
3. If pipeline → `/api-resource-pipeline` or `/api-resource-ship`.
4. If atomic → use the relevant `/symfony-api-*` command or invoke the skill/agent directly.
5. Refer to `docs/symfony/pipeline-overview.md` for full Mermaid.

## When to use which mode

| Situation | Recommended |
|---|---|
| New API resource end-to-end | `/api-resource-pipeline` |
| Refactor an existing resource (medium complexity) | `/api-resource-pipeline` |
| Fix a bug (single file, one line) | Atomic skill or direct edit |
| Bump a dependency | Atomic |
| Migrate from `#[ApiFilter]` to `parameters: [QueryParameter]` | `Skill({ skill: "gerard:api-platform-upgrade" })` then atomic edits |
| Ship a feature on a Friday evening, hands-off | `/api-resource-ship` |
| Critical change you want to inspect | `/api-resource-pipeline` (stops before commit) |

## Guardrails

- **`/api-resource-ship` only with passing prerequisites**: clean working tree, `.claude/settings.json` denying `--force`/`--no-verify`.
- **State files are runtime, not source**: `.claude/last-api-*.md` are gitignored.
- **Authority order**: project CLAUDE.md > stage personas > project skills layer (`<project>:X`) > plugin canon (`gerard:*`).
- **Skill dispatch theatre is rejected**: every claimed skill dispatch must have an actual `Skill()` / `Task()` call in the tool stream. The reviewer enforces.

## Progressive disclosure

- This file for the entry-point map
- `docs/symfony/pipeline-overview.md` for the full pipeline architecture (Mermaid)
- `docs/symfony/agentic-personas.md` for the 7 agents detailed
- `docs/symfony/state-files-protocol.md` for `.claude/last-api-*.md` convention
- `docs/symfony/marker-protocol.md` for `===STAGE-BEGIN===` format
- `docs/symfony/project-skills-pattern.md` for the project skills layer pattern
- `docs/symfony/forensic-audit-template.md` for the ship → measure → tighten loop
- `docs/symfony/api-platform-anti-patterns.md` for the canonical anti-pattern catalog
- `skills-map.md` for the full index of the 53 `gerard:*` skills (grouped by domain)
- `docs/complexity-tiers.md` to adapt verbosity and granularity to project tier (Simple / Medium / Complex)

## Output contract

- A user that runs `/architect "<story>"` for the first time understands the next step.
- A team adopting the plugin can configure their `<project>:X` overrides and `.claude/settings.json` correctly.

## References

- All `docs/symfony/*.md`
- `docs/complexity-tiers.md` (project-tier playbook)
- `skills-map.md` / `skills-map-lite.md` (skill index)
- `README.md` (user-facing entry point)
