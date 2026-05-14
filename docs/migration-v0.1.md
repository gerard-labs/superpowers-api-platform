# Migrating from v0.1 to v1.0

> v1.0 is a **big bang rebuild**. The user-facing surface shrinks from 25 commands to 3 ; the agent count drops from 7 to 3 ; the bespoke state-file orchestration is replaced by native Claude Code `/goal`. This doc walks you through the migration end-to-end.

## TL;DR

If you used v0.1's `/api-resource-pipeline` or `/api-resource-ship` commands, the new equivalent is :

```text
# v0.1
/api-resource-pipeline "Add Product resource"

# v1.0
/api "Add Product resource"
```

That's the most common case. Read on if you used other commands or want the full mapping.

---

## What changed

### Commands

| v0.1 | v1.0 |
|---|---|
| `/architect`, `/dev`, `/test`, `/review` (4 commands) | Removed. Internal agent dispatches under `/api`. |
| `/api-resource-pipeline`, `/api-resource-ship` | Removed. `/api` + `/api-finalize`. |
| `/self-audit-api` | Removed as command. Available as a skill : `gerard:anti-patterns-audit`. Invoke via `Skill` tool. |
| 13 atomic `/symfony-*` commands (`/symfony-api-resources`, `/symfony-api-filters`, `/symfony-api-mcp`, `/symfony-api-mutators`, `/symfony-api-errors`, `/symfony-api-upgrade`, `/symfony-voters`, `/symfony-messenger`, `/symfony-cache`, `/symfony-tdd-pest`, `/symfony-tdd-phpunit`, `/symfony-migrations`, `/symfony-fixtures`, `/symfony-doctrine-relations`, `/symfony-check`) | All removed. The Skill tool natively invokes the corresponding `gerard:*` skill. Replace `/symfony-api-filters` with `Skill gerard:api-platform-filters` (or just let `/api` dispatch via keyword detection). |
| `/brainstorm`, `/write-plan`, `/execute-plan` | Removed. Claude Code natively supports plan mode + native primitives. |

**New** :

| Command | Description |
|---|---|
| `/api <story>` | Single entry point. Architects → implements → reviews → goal-clear. |
| `/api-finalize` | Commit + push + open PR (separate step on purpose — inspection point). |
| `/api-doctrine export\|import\|list` | Memory snapshot management (M3 hybrid auto-memory). |

### Agents

| v0.1 | v1.0 |
|---|---|
| `api-platform-architect` | Fused into `api-architect-trio` (dispatch + synthesis). |
| `api-platform-aligned-reviewer` | Becomes a background worker dispatched in parallel by `api-architect-trio`. |
| `api-platform-appsec` | Becomes a background worker dispatched in parallel by `api-architect-trio`. |
| `api-platform-implementer` | Renamed `api-implementer`. Enriched with `memory/` dir. |
| `symfony-tdd-coach` | Removed as agent. Doctrine moved into skills `tdd-php` + `api-platform-tests`. The implementer writes tests directly now. |
| `symfony-reviewer` | Renamed `gerard-gatekeeper`. Enriched with `memory/` dir + Sonnet 4.6 explicit. Adversarial fresh session. |
| `doctrine-architect` | Removed as agent. Doctrine covered by existing skills (`doctrine-relations`, `doctrine-migrations`, etc.). |

### Skills

| v0.1 | v1.0 |
|---|---|
| `tdd-with-pest` + `tdd-with-phpunit` | **Fused** into `tdd-php` with framework routing via `test_framework` from session-start. Both squelettes inline in one SKILL.md. |
| `bootstrap-check` | **Absorbed** into `daily-workflow`. |
| (none) | **Added** : `anti-patterns-audit` (standalone audit), `goal-patterns` (the 9 `/goal` templates). |

Net : 53 skills in v0.1, 53 skills in v1.0 (different composition — 2 fused, 1 absorbed, 2 new cross-cutting skills `anti-patterns-audit` + `goal-patterns`).

**Effort-routing added** on the 20 `api-platform-*` skills + `tdd-php` + both cross-cutting skills (`anti-patterns-audit`, `goal-patterns`). `/api --effort low|high|xhigh` propagates.

### Hooks

| v0.1 | v1.0 |
|---|---|
| 1 hook (`session-start.sh` only) | **5 hooks** : SessionStart + UserPromptSubmit + PreToolUse + PostToolUse + Stop. Each with a tightly-scoped job. |

`session-start.sh` itself was enhanced with Claude Code version check and richer command surfacing.

### State files & marker protocol

| v0.1 | v1.0 |
|---|---|
| `.claude/last-api-plan.md` (architect output) | Removed. Task return is the contract. |
| `.claude/last-api-dev-report.md` (implementer output) | Removed. Task return. |
| `.claude/last-api-test-report.md` (test output) | Removed. Implementer writes tests directly. |
| `.claude/last-api-review.md` (review output) | Removed. Task return. |
| `===STAGE-BEGIN===` / `===STAGE-END===` marker protocol | Removed. Task returns are deterministic. |
| Hard-coded `REQUEST_CHANGES` cap (3) | Replaced by `/goal` 12-turn cap. |

If your project has legacy `.claude/last-api-*.md` files lying around, `/api-finalize` ignores them at staging time. You can delete them when you're comfortable.

### Other

- `samurai-build` / `samurai/` example references in skills/runner-selection, skills/makefile-discipline, RELEASE-NOTES were replaced by neutral examples or removed.
- `skills-map-lite.md` removed. `skills-map.md` remains as the index.
- Plugin namespace stays `gerard:`. No change to skill / command / agent invocation prefixes.

---

## Step-by-step migration

### 0. Verify your environment

```bash
claude --version
# Output should be ≥ 2.1.139
```

v1.0 needs Claude Code 2.1.139+ for native `/goal`, `Monitor`, and `Agent` with `isolation: "worktree"`. If you're on an older version, update first.

### 1. Update the marketplace and plugin

```text
/plugin marketplace update gerard@superpowers-api-platform
/plugin update gerard@superpowers-api-platform
```

The marketplace will fetch the v1.0 release. The update is in-place — no need to uninstall and reinstall.

### 2. Read the docs

In your shell of choice (or directly via Claude Code) :

```bash
cd ~/.claude/plugins/marketplaces/superpowers-api-platform/
cat docs/overview.md            # 5-min read
cat docs/how-it-works.md        # architecture deep-dive
cat docs/commands.md            # /api reference
```

### 3. Replace your habitual commands

| Habit | Replace with |
|---|---|
| `/api-resource-pipeline "story"` | `/api "story"` |
| `/api-resource-ship "story"` | `/api "story"` then `/api-finalize` (split, on purpose) |
| `/architect "story"` | (gone) Use `/api "story"` and rely on the internal architect-trio dispatch. For design-only work : `@agent-api-architect-trio` directly. |
| `/dev` | (gone) Implementer is invoked under `/api`. For ad-hoc impl : `@agent-api-implementer`. |
| `/review` | (gone) Gatekeeper invoked under `/api`. For ad-hoc review : `@agent-gerard-gatekeeper`. |
| `/self-audit-api` | `Skill gerard:anti-patterns-audit` |
| `/symfony-api-filters` | `Skill gerard:api-platform-filters` (or just type a story like *"Add a filter on Product"* and let `/api` route it) |
| `/symfony-tdd-pest` / `/symfony-tdd-phpunit` | `Skill gerard:tdd-php` (auto-routes to your framework) |
| `/brainstorm` | (gone) Use Claude Code native plan mode. |
| `/write-plan` / `/execute-plan` | (gone) Skills `gerard:writing-plans` and `gerard:executing-plans` remain for non-`/api` hors-pipeline use. |

### 4. Clean up legacy state files (optional)

```bash
rm -rf .claude/last-api-*.md   # if any leftover from v0.1
```

`/api-finalize` already ignores them at staging time, but removing keeps the repo clean.

### 5. Decide on memory strategy

v1.0 adds per-agent `memory/` directories and the `/api-doctrine` snapshot command. Two choices :

- **Default (recommended)** : let memory accumulate naturally. Read [`forensic-loop.md`](forensic-loop.md) to understand the pattern.
- **Versionable doctrine** : after a few productive runs, `/api-doctrine export <name>` and commit the snapshot. Useful for team handoffs.

### 6. Verify

Run a small story end-to-end :

```text
/api "Add a Foo resource with a single name field for smoke testing"
```

Watch for :

- ✅ session-start hook fires (you'll see a brief env detection log)
- ✅ user-prompt-submit hook injects `additionalContext` (skills relevant to "Add resource")
- ✅ architect-trio dispatches 3 background workers (look for `Monitor` events)
- ✅ implementer writes code + tests, PostToolUse hook runs phpstan inline
- ✅ gatekeeper opens in a fresh session and returns `VERDICT: APPROVE`
- ✅ `/goal` clears, desktop notification fires
- ✅ `/api-finalize` builds the staging list and commits explicitly

If any step misbehaves, see [`troubleshooting.md`](troubleshooting.md).

---

## FAQ

### Why was `/architect`/`/dev`/`/test`/`/review` removed?

The four commands were thin shells around four agents that always ran in the same order. v1.0 makes the order implicit (under `/api`) and makes the dispatch dynamic (architect-trio dispatches 3 background workers in parallel). The user-facing surface shrinks ; the orchestration gets more powerful.

### Why was `/self-audit-api` removed?

It's still available — as `Skill gerard:anti-patterns-audit`. Skills are first-class citizens, invocable from any agent or directly by the user via the `Skill` tool. Removing the slash command sheds ceremony without losing the capability.

### Why were the 13 `/symfony-*` atomic commands removed?

Each was a one-liner that invoked one `gerard:*` skill. The `Skill` tool does this natively now — type `Skill gerard:api-platform-filters` instead of `/symfony-api-filters`. Same skill, less wrapping.

Alternatively, `/api` does **keyword-based skill pre-fetching** via the UserPromptSubmit hook : type *"Add a filter on Product"* and the relevant skills get hinted automatically without you needing to remember which one.

### What happened to `symfony-tdd-coach` agent?

Doctrine moved into the `gerard:tdd-php` skill. The implementer agent now writes tests directly while reading the doctrine on demand. One less agent round-trip per cycle.

### Are my v0.1 state files still useful?

No. The implementer and gatekeeper read their Task inputs directly. Legacy `.claude/last-api-*.md` files are ignored ; `/api-finalize` skips them at staging.

### Will my `.claude/skills/<project>/` overrides still work?

Yes. The override mechanism is unchanged in v1.0. `<project>:X` takes priority over `gerard:X` when both exist.

### What about the `/goal` 12-turn cap?

It replaces the v0.1 hard-coded "3 REQUEST_CHANGES cycles" cap. 12 turns gives more room for the implementer ⇄ gatekeeper loop to converge. The cap is a safety net ; most runs converge in 2-4 turns.

### Can I run v1.0 alongside v0.1?

No. The plugin namespace `gerard:` is shared. v1.0 replaces v0.1 — they can't coexist in the same Claude Code session. If you need both, install them under different marketplace names (would require forking the plugin and renaming).

### Is there an automated migration script?

No. The migration is manual but small : update the plugin, replace 3-5 habitual command invocations with their v1.0 equivalents, optionally clean up legacy state files. The `/api` command does most of the heavy lifting once installed.

---

## What if I hit a regression?

1. Check [`troubleshooting.md`](troubleshooting.md) for the symptom.
2. If it's not there, open an issue : [github.com/gerard-labs/superpowers-api-platform/issues](https://github.com/gerard-labs/superpowers-api-platform/issues). Include :
   - The exact `/api` story you ran
   - The point at which it diverged from expected (architect-trio? implementer? gatekeeper?)
   - The output of `claude --version` and the session-start hook's env JSON (visible in the system reminder area)

Fast feedback : the project is maintained by `gerard-labs` and PRs are welcome.

---

## References

- [`v1.0-plan.md`](v1.0-plan.md) — internal big-bang plan with full rationale
- [`overview.md`](overview.md) — 5-min read for the v1.0 mental model
- [`how-it-works.md`](how-it-works.md) — architecture deep-dive
- [`commands.md`](commands.md) — `/api`, `/api-finalize`, `/api-doctrine` reference
- [`anti-patterns.md`](anti-patterns.md) — the canonical 24-rule checklist (was distributed across files in v0.1)
- [`forensic-loop.md`](forensic-loop.md) — the new memory pattern (no v0.1 equivalent)
- [`troubleshooting.md`](troubleshooting.md) — common errors
