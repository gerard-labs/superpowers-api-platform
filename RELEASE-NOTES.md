# Release notes

## v1.0.0 (2026-05-14) — Big bang rebuild

**The biggest release since the plugin shipped.** v1.0 is a ground-up rebuild that exploits Claude Code 2026 primitives (native `/goal`, `Monitor`, per-agent memory directories, Dreaming consolidation, multi-model orchestration, worktree isolation). The user-facing surface goes from 25 commands to 3 ; the orchestration code shrinks by ~80% ; the doctrinal content stays intact.

### Highlights

- **3 agents, 3 commands** — `/api`, `/api-finalize`, `/api-doctrine`. Internal architect-trio + implementer + gatekeeper. Multi-model orchestration : Opus 4.7 (xhigh) for the architect lead, Sonnet 4.6 for workers and gatekeeper, Haiku 4.5 for `/goal` evaluation. ~30-40% fewer tokens than all-Opus.
- **Native `/goal` loop** — no bespoke state files, no `===STAGE-BEGIN===` markers, no hard-coded REQUEST_CHANGES counter. The Claude Code 2.1.139+ `/goal` primitive drives the implementer ⇄ gatekeeper loop with a verifiable condition + Haiku evaluator. Cap : 12 turns.
- **5 hooks** — bash, deterministic. SessionStart (env detection + version check), UserPromptSubmit (keyword-based skill pre-fetch), PreToolUse (secret-file write block), PostToolUse (7-regex + phpstan inline), Stop (desktop notification).
- **Per-agent memory + Dreaming** — each agent owns `agents/<name>/memory/` and accumulates short topical findings across sessions. Dreaming consolidates between sessions. `/api-doctrine export/import` versions the doctrine.
- **39-rule adversarial review** — the gatekeeper opens in a fresh session (no shared context with implementer) and applies 16 API Platform 4.3 + 8 Symfony 7.4+ + 1 project-conventions + 7 tests + 7 AppSec rules. Strict `VERDICT: APPROVE` / `REQUEST_CHANGES` format.
- **Skill effort-routing** — the 20 `api-platform-*` skills + `tdd-php` + both `meta/*` declare an `effort:` block. `/api --effort low|high|xhigh` propagates : `low` reads SKILL.md only, `xhigh` loads SKILL.md + reference.md + project overrides + edge cases.
- **53 skills** — same count as v0.1 with cleaner composition : `tdd-with-pest` + `tdd-with-phpunit` fused into `tdd-php` (framework routing via `test_framework`), `bootstrap-check` absorbed into `daily-workflow`, two new skills under `meta/` (`anti-patterns-audit`, `goal-patterns`).
- **Verified docs overhaul** — README rewritten with badges + mermaid + features table. 10 new `docs/` files including a 5-min `overview.md`, deep-dive `how-it-works.md`, full `commands.md` / `agents.md` / `hooks.md` / `skills.md`, canonical `anti-patterns.md`, `goal-patterns.md`, `forensic-loop.md`, `migration-v0.1.md`, `troubleshooting.md`.

### Breaking changes

This is a big bang. **No back-compat with v0.1.** Read [`docs/migration-v0.1.md`](docs/migration-v0.1.md) for the full migration walkthrough.

#### Commands removed

- `/architect`, `/dev`, `/test`, `/review` — replaced by internal agent dispatch under `/api`.
- `/api-resource-pipeline`, `/api-resource-ship` — replaced by `/api` + `/api-finalize` (separate steps on purpose).
- `/self-audit-api` — available as `Skill gerard:anti-patterns-audit`.
- 13 atomic `/symfony-*` commands (`/symfony-api-resources`, `/symfony-api-filters`, `/symfony-api-mcp`, `/symfony-api-mutators`, `/symfony-api-errors`, `/symfony-api-upgrade`, `/symfony-voters`, `/symfony-messenger`, `/symfony-cache`, `/symfony-tdd-pest`, `/symfony-tdd-phpunit`, `/symfony-migrations`, `/symfony-fixtures`, `/symfony-doctrine-relations`, `/symfony-check`) — the Skill tool natively invokes the corresponding `gerard:*` skill.
- `/brainstorm`, `/write-plan`, `/execute-plan` — Claude Code natively supports plan mode + primitives.

#### Agents removed or renamed

- `api-platform-architect` → fused into `api-architect-trio` (dispatch + synthesis).
- `api-platform-aligned-reviewer` → becomes a background worker under `api-architect-trio`.
- `api-platform-appsec` → becomes a background worker under `api-architect-trio`.
- `api-platform-implementer` → renamed `api-implementer`, enriched with `memory/` dir.
- `symfony-tdd-coach` → removed as agent ; doctrine moved into skills `tdd-php` + `api-platform-tests`.
- `symfony-reviewer` → renamed `gerard-gatekeeper`, enriched with `memory/` dir + Sonnet 4.6 explicit.
- `doctrine-architect` → removed as agent ; doctrine covered by existing `doctrine-*` skills.

#### Skills changed

- `tdd-with-pest` + `tdd-with-phpunit` → fused into `tdd-php`. Routing via `test_framework` from session-start. Both squelettes inline.
- `bootstrap-check` → absorbed into `daily-workflow`.
- `skills/anti-patterns-audit/` — new (the standalone ex-`/self-audit-api`).
- `skills/goal-patterns/` — new (the `/goal` condition templates).

#### State files & marker protocol removed

- `.claude/last-api-plan.md`, `.claude/last-api-dev-report.md`, `.claude/last-api-test-report.md`, `.claude/last-api-review.md` — Task returns replace them.
- `===STAGE-BEGIN===` / `===STAGE-END===` marker protocol — Task returns are deterministic.
- Hard-coded REQUEST_CHANGES cap (3) — replaced by `/goal` 12-turn cap.

#### Hooks expanded

- v0.1 had 1 hook (`session-start.sh`). v1.0 has **5** : SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop. Each has a tightly-scoped job.
- `session-start.sh` itself was enhanced with a Claude Code version check (warns if `< 2.1.139`) and richer command surfacing (`commands.console`, `commands.test`, `commands.ci`, `commands.quality`, `commands.migrations`).

#### Repository changes

- `skills-map-lite.md` removed. `skills-map.md` remains.
- `samurai-build` / `samurai/` example references replaced by neutral examples (in `skills/runner-selection`, `skills/makefile-discipline`).
- Plugin namespace unchanged (`gerard:`).

### Multi-model orchestration

Explicit model assignment per component :

| Component | Model | Rationale |
|---|---|---|
| `api-architect-trio` (lead synthesis) | Opus 4.7 xhigh | Architecture is the riskiest stage. Synthesis must preserve verbatim blocks coherently. |
| Background workers (design / aligned / appsec) | Sonnet 4.6 | Tightly-scoped doctrinal prompts ; three Sonnets in parallel cost ~30% of one Opus session. |
| `api-implementer` | Opus 4.7 high | Sustained context for skill reading + code writing + iteration. |
| `gerard-gatekeeper` | Sonnet 4.6 (fresh session) | Deterministic rule-matching ; fresh session matters more than model class. |
| `/goal` evaluator | Haiku 4.5 (Claude Code default) | Tiny matching task. |

### Migration

For users upgrading from v0.1 :

```text
/plugin marketplace update gerard@superpowers-api-platform
/plugin update gerard@superpowers-api-platform
```

Then read [`docs/migration-v0.1.md`](docs/migration-v0.1.md). The migration is mostly habit-replacement (3-5 commands swapped) ; the marketplace update handles the rest.

### Supported versions

| Framework | Version | Status |
|---|---|---|
| Claude Code | **2.1.139+** | Required (native `/goal`, `Monitor`, worktree isolation) |
| API Platform | **4.3+** | Required |
| Symfony | **7.4 LTS** (released Nov 2025) | Required |
| Symfony | **8.0+** | Supported |
| PHP | **8.2+** | Required |

Older versions are out of scope. The session-start hook warns and points to `gerard:api-platform-upgrade` for migration.

### Out of scope (intentionally not in v1.0)

- **Cloud features** — no Routines, no `ultrareview` integration, no `claude -p` plan-user dependency. The plugin is 100% local interactive. Decision verrouillée — see [`docs/v1.0-plan.md`](docs/v1.0-plan.md) section 1.
- **Multi-channel reach (universal skills)** — gerard stays Claude-Code-only. The strategy is *deep* exploitation of Claude features, not *broad* reach across tools.
- **Split plugins** — mono-plugin. No `gerard-canon` / `gerard-pipeline` split.
- **Older Symfony / API Platform** — same as v0.1, < 7.4 / < 4.3 are migration targets, not supported runtimes.

### Acknowledgments

Built on top of Claude Code 2.1.139+ and the Claude Sonnet 4.6 / Opus 4.7 / Haiku 4.5 model family. Research that shaped the decision-making :

- **Multi-agent vs single-agent coding** : [Anthropic — Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents), [arxiv — Dive into Claude Code design space](https://arxiv.org/html/2604.14228v1), CORE framework benchmarks.
- **Adversarial fresh-session review** : [Adversarial Code Review pattern](https://asdlc.io/patterns/adversarial-code-review/).
- **Dreaming / managed agents** : [Anthropic Dreaming announcement](https://letsdatascience.com/blog/anthropic-dreaming-claude-managed-agents-self-improving-may-6) (May 2026 research preview).
- **Competitive landscape Q1-Q2 2026** : Cursor 2.0 changelog, Bugbot learning, Agent Skills as open standard.

Full sources in [`docs/v1.0-plan.md`](docs/v1.0-plan.md) Annexe A.

### License

MIT — unchanged.

---

## v0.1.0 (2026-05-14) — Initial release

First public release of the `gerard` plugin for Claude Code, distributed via the `superpowers-api-platform` marketplace.

The plugin targeted **API Platform 4.3+** running on **Symfony 7.4 LTS+** exclusively. It shipped skills, agents, slash commands and a session-start hook to scaffold and review API resources, DTOs, state providers/processors, modern filters, security, MCP, Object Mapper, Mutators, Scalar UI, ErrorResource, identifiers (UUID v7 / ULID), resilience patterns, performance tuning, and exhaustive tests.

### What was included

**Plugin namespace**: `gerard` (skills, commands and agents are exposed as `gerard:*`).

**Marketplace**: `superpowers-api-platform` (`gerard-labs/superpowers-api-platform` on GitHub).

#### 53 skills

- **20 API Platform 4.3** — resources, DTO resources (Object Mapper), state providers, state processors, serialization, security, modern filters (`parameters` + `QueryParameter`), tests, versioning, pagination, performance, resilience, errors (RFC 7807 + `#[ErrorResource]`), identifiers (UUID v7 / ULID), OpenAPI + Scalar UI, MCP (@experimental), Mutators (`#[AsResourceMutator]` / `#[AsOperationMutator]`), user / password / `/me`, file upload (Vich + MediaObject), upgrade (3.x / 4.0-4.2 → 4.3).
- **24 Symfony 7.4+ core** — Messenger + retry strategies, scheduler, voters, rate limiting, cache, controller cleanup, interfaces + autowiring, ports & adapters (Deptrac), CQRS + handlers, value objects + DTOs, config / env / parameters, strategy pattern, Doctrine (relations, migrations, fixtures via Foundry, transactions, fetch modes, batch processing), TDD (Pest + PHPUnit), functional tests, test doubles, quality checks (PHP-CS-Fixer, PHPStan, Infection, `composer audit`, Renovate).
- **9 workflow** — entry point, runner selection, Makefile discipline, bootstrap check, daily workflow, effective context, brainstorming, writing plans, executing plans.

#### 7 specialized agents

`api-platform-architect`, `api-platform-aligned-reviewer`, `api-platform-appsec`, `api-platform-implementer`, `symfony-tdd-coach`, `symfony-reviewer`, `doctrine-architect`.

The 3 architecture personas were dispatched in parallel from `/architect`.

#### 25 slash commands

- **Pipeline (7)** — `/architect`, `/dev`, `/test`, `/review`, `/api-resource-pipeline`, `/api-resource-ship`, `/self-audit-api`.
- **Atomic (18)** — 13 `/symfony-*` wrappers + `/brainstorm`, `/write-plan`, `/execute-plan`, `/symfony-check`.

#### Session-start hook

Detected Symfony, API Platform, orchestration root, runner type, test framework, Make targets.

#### Pipeline state files

`.claude/last-api-*.md` per stage with `===STAGE-BEGIN===` / `===STAGE-END===` markers.

#### Project skills layer

`.claude/skills/<project>/*.md` overrides — preserved as a feature in v1.0.

#### Anti-regression lint

`scripts/lint_skill_content.ts` rejected pre-4.3 API Platform patterns outside of `api-platform-upgrade`.

### License

MIT.
