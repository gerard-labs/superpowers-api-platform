# Contributing to gerard

> Thanks for considering a contribution. This doc covers the conventions for skills, agents, hooks, commands, and the validation gates a PR must pass.

## Quick checklist before opening a PR

```bash
# 1. Run the validator
npx tsx scripts/validate_skills.ts
# Expected: 53 valid skills, 3 valid commands, "All validations passed!"

# 2. Run the content linter (catches pre-4.3 patterns outside of api-platform-upgrade)
npx tsx scripts/lint_skill_content.ts

# 3. Sanity check the hook syntax
for f in hooks/*.sh; do bash -n "$f"; done
```

If any of those fail, fix the underlying issue ; don't paper over with skips or excludes.

---

## Repository layout

```
.
├── .claude-plugin/             # plugin manifest + marketplace
├── agents/                     # 3 agents (architect-trio, implementer, gatekeeper)
│   ├── api-architect-trio/
│   │   ├── agent.md            # frontmatter + body
│   │   └── memory/.gitkeep     # accumulates findings
│   ├── api-implementer/
│   └── gerard-gatekeeper/
├── commands/                   # 3 user-facing commands
│   ├── api.md
│   ├── api-finalize.md
│   └── api-doctrine.md
├── docs/                       # public docs + internal v1.0-plan
├── hooks/                      # 5 bash hooks + hooks.json
├── scripts/                    # validators (validate_skills.ts, lint_skill_content.ts)
├── skills/                     # 53 skills (including 2 under meta/)
├── tests/
│   ├── fixtures/               # E2E fixture (Symfony 7.4 + AP 4.3)
│   └── hooks/                  # bash test scripts
├── skills-map.md               # index pointing into skills/
├── README.md
├── RELEASE-NOTES.md
├── CONTRIBUTING.md             # this file
├── LICENSE
└── package.json                # validator dev deps
```

---

## Skills

### Format

Each skill is a directory containing `SKILL.md` (concise trigger + workflow). Skills with deeper doctrine also ship `reference.md` (full content).

```markdown
---
name: api-platform-filters
description: >
  Trigger-friendly description with concrete keywords (filter, search, sort,
  parameters, QueryParameter). The first 2 lines drive Claude's skill
  discovery — be specific.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
effort:                        # optional — for skills with reference.md
  low:   SKILL.md only — "Use when" + default workflow + key bullets.
  high:  SKILL.md + reference.md — full doctrine.
  xhigh: SKILL.md + reference.md + project overrides + edge cases.
---

# Skill content
- Use when …
- Default workflow …
- Anti-patterns …
```

### Frontmatter rules

- `name` must match the directory name (kebab-case).
- `description` should mention concrete trigger keywords (the same words a user would type) — Claude reads it for skill matching.
- `allowed-tools` is the set of tools the skill body assumes. Be honest — if the skill needs `Bash`, list `Bash`.
- `effort:` is optional and only meaningful when a `reference.md` exists. Used by `/api --effort low|high|xhigh`.

### Don't prefix `gerard:` in the `name` field

The namespace is applied automatically by Claude Code from `.claude-plugin/plugin.json` (`"name": "gerard"`). Writing `name: gerard:api-platform-filters` would double-prefix.

### When to add a new skill

- A pattern recurs across stories and isn't covered by existing skills.
- A new framework primitive ships (e.g. Symfony adds a new component you'd use ; API Platform releases a 4.4 feature). New skill, not an edit to an existing one — keep skills focused.
- A project consistently wants a specialized variant (then prefer a project override, not a plugin skill — see [project overrides](#project-overrides) below).

### When NOT to add a new skill

- The doctrine already lives in another skill, just deeper than you remembered. Read the existing skill first.
- The story is one-off (you'll never see it again). One-off doctrine belongs in the project's `.claude/skills/<project>/`, not in `gerard:`.
- The "skill" is two paragraphs that could be a section in an existing skill. Edit the existing skill.

### Project overrides

A consuming project can ship `.claude/skills/<project-name>/<skill>/SKILL.md` to override the plugin canon for that skill. Naming convention `<project>:X` takes priority over `gerard:X` when both exist. See [`docs/skills.md`](docs/skills.md#project-overrides).

---

## Agents

### Format

Each agent is a directory containing `agent.md` + a `memory/` subdir.

```markdown
---
name: api-architect-trio
description: >
  One-paragraph description Claude reads before deciding to dispatch the agent.
  Concrete keywords + role + I/O shape.
model: opus-4.7-xhigh             # or opus-4.7-high, sonnet-4.6, haiku-4.5
effort: high                       # low | high | xhigh — internal effort knob
maxTurns: 25
tools:                             # tools the agent uses
  - Read
  - Glob
  - Grep
  - Bash
  - Agent
  - Monitor
skills:                            # skills the agent may dispatch
  - gerard:api-platform-resources
  - gerard:api-platform-filters
memory: project                    # memory scope
---

# Agent body — workflow, prompts, anti-patterns to guard against
```

### Memory directory

Every agent ships `agents/<name>/memory/.gitkeep` so the directory exists on fresh clones. The agent reads the directory as its **first action** and writes one short topical file at the end of a session **only if a new pattern emerged**. Memory is not a journal — see [`docs/forensic-loop.md`](docs/forensic-loop.md) for the discipline.

### When to add an agent

You probably don't. v1.0 settled on **3 agents** after research and benchmarks. Adding a fourth agent fragments the orchestration ; the bar is high.

If you think you need a new agent : open an issue first and discuss. Often what feels like an agent is actually a skill.

---

## Hooks

### Format

Hooks are bash scripts under `hooks/`. They are registered in `hooks/hooks.json` and invoked by Claude Code at lifecycle events.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Read stdin JSON payload
payload=$(cat || true)
if [[ -z "$payload" ]] || ! command -v jq &>/dev/null; then
  exit 0
fi

# Extract fields
prompt=$(echo "$payload" | jq -r '.prompt // empty')

# Do work
# ...

# Emit JSON response if blocking or injecting
jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
```

### Hook rules

- **Exit 0 on the no-op path.** Hooks fire on every event ; noise erodes trust.
- **Use `set -euo pipefail`.** Bash unset variables and pipe failures should fail loudly during dev, not silently in prod.
- **Use `jq` for JSON.** Don't try to parse / emit JSON with `sed` or string concat. If `jq` is missing, `exit 0`.
- **Be deterministic.** The hook's job is to be a reliable enforcer. If it can be ambiguous, push the ambiguity to an agent (subjective review) instead.
- **Keep them fast.** PostToolUse fires on every file write. 30s phpstan timeout is the upper bound ; faster is better.

### Adding a new hook

Edit `hooks/hooks.json` to declare the event, then ship the script.

The 5-hook list (SessionStart + UserPromptSubmit + PreToolUse + PostToolUse + Stop) is intentionally small. If you find yourself reaching for a 6th hook, ask whether the work belongs in an existing hook or in the gatekeeper agent.

---

## Commands

### Format

```markdown
---
description: One-line description shown in /help and Claude Code UI.
argument-hint: "<arg shape>"
allowed-tools: Bash, Read, Glob, Grep
---

# /command-name — title

Body : workflow with `!shell` invocations for inline bash, mermaid diagrams,
checklist of hard rules. Reference skills and agents by their full `gerard:` /
`@agent-` names.
```

### Command rules

- **3 user-facing commands** is the v1.0 contract. The 25 → 3 reduction is documented in [`docs/v1.0-plan.md`](docs/v1.0-plan.md). Adding a 4th command requires strong justification.
- **Pre-flight is mandatory** for any command that mutates state (`/api`, `/api-finalize`). Hard-fail on dirty tree, wrong branch, mid-rebase.
- **Stage explicitly** (`/api-finalize`). Never `git add -A` / `.`.
- **No `--no-verify` / `--amend`.** Hook failures are signals, not obstacles.

### Adding a new command

Open an issue first. The 3-command surface is part of the v1.0 ergonomics.

---

## Tests (E2E fixture)

Under `tests/fixtures/symfony-test-project/` — a minimal Symfony 7.4 + API Platform 4.3 setup used by Session 7 of the big-bang to validate the plugin end-to-end. If you're touching agent / hook / command code, run the fixture scenarios before opening a PR. See `tests/test-report-v1.0.md` (created during Session 7) for the protocol.

Hook unit tests under `tests/hooks/` — bash test scripts for the session-start hook environment detection. Run with `bash tests/hooks/session-start.test.sh`.

---

## Validators

### `scripts/validate_skills.ts`

Walks `skills/`, `agents/`, `commands/` and validates :

- Frontmatter shape (required keys per artefact type)
- `name` matches the directory
- `allowed-tools` / `tools` are valid tool names
- `effort:` block is well-formed (optional)
- Skills under `skills/meta/` are recursively validated as a namespace

Run :

```bash
npx tsx scripts/validate_skills.ts
```

Expected output : `53 valid skills, 3 valid commands, All validations passed!`

### `scripts/lint_skill_content.ts`

Scans skill content for pre-4.3 API Platform patterns (`#[ApiFilter]`, `openapiContext`, `hydra:` prefix, etc.). Rejects any hit outside `skills/api-platform-upgrade/`.

```bash
npx tsx scripts/lint_skill_content.ts
```

If you genuinely need to document a legacy pattern (as a counter-example), put it in `api-platform-upgrade` ; the linter exempts that path.

---

## Commit message convention

```
<scope>: <subject — imperative, ≤ 72 chars>

[optional body — Why / What / Verification]
```

Examples :

- `v1.0: docs big bang phase 6`
- `skills: fuse tdd-with-pest and tdd-with-phpunit into tdd-php`
- `hooks: tighten post-tool-use regex for hard-coded URL detection`

No "Generated by Claude" trailer.

---

## Branching

- `main` is the released branch. Tags : `v1.0.0`, `v1.0.1`, etc.
- `v1.0` is the big-bang feature branch (merged into `main` at v1.0.0 release).
- Feature branches : `<scope>/<short-slug>` (e.g. `skills/add-doctrine-design`, `docs/update-troubleshooting`).

---

## Code style

- **Bash hooks** : POSIX-ish but use bash arrays / `[[ ]]` freely. `set -euo pipefail`. 2-space indent. Use `jq` for JSON.
- **TypeScript validators** : strict mode (`"strict": true` in `tsconfig.json`). Prefer `for ... of` over `forEach`. Throw on validation failure ; don't return `false`.
- **Markdown** : ATX headings (`#` not `===`), GFM tables, fenced code blocks with language tag. Reference files with `[label](path)` (relative paths).

---

## Documentation

When you add or change a feature :

1. Update the relevant `docs/*.md` (the user-facing surface).
2. Update `README.md` if the feature affects the top-level pitch.
3. Update `RELEASE-NOTES.md` with the change under "Unreleased" (or the next release header).
4. Update `docs/v1.0-plan.md` **only if** the user explicitly validates a doctrine change — it's a canonical reference, not a changelog.

Skip `docs/v1.0-plan.md` for ordinary feature work.

---

## Reporting bugs / opening discussions

- Issues : [github.com/gerard-labs/superpowers-api-platform/issues](https://github.com/gerard-labs/superpowers-api-platform/issues)
- Discussions : [github.com/gerard-labs/superpowers-api-platform/discussions](https://github.com/gerard-labs/superpowers-api-platform/discussions)

When reporting a bug, include :

- `claude --version`
- The `/api` story (or specific command) that triggered it
- The output (especially gatekeeper VERDICT / EVIDENCE block if relevant)
- Session-start hook env JSON (visible in the system reminder area)

---

## License

MIT (see [`LICENSE`](LICENSE)). By contributing, you agree to license your contribution under the same terms.
