# Release notes

## v0.1.0 (2026-05-14) — Initial release

First public release of the `gerard` plugin for Claude Code, distributed via the `superpowers-api-platform` marketplace.

The plugin targets **API Platform 4.3+** running on **Symfony 7.4 LTS+** exclusively. It ships skills, agents, slash commands and a session-start hook to scaffold and review API resources, DTOs, state providers/processors, modern filters, security, MCP, Object Mapper, Mutators, Scalar UI, ErrorResource, identifiers (UUID v7 / ULID), resilience patterns, performance tuning, and exhaustive tests.

### What's included

**Plugin namespace**: `gerard` (skills, commands and agents are exposed as `gerard:*`). The namespace is applied automatically by Claude Code from `.claude-plugin/plugin.json` — `SKILL.md` `name:` frontmatter must stay bare (no prefix).

**Marketplace**: `superpowers-api-platform` (`gerard-labs/superpowers-api-platform` on GitHub).

#### 53 skills

- **20 API Platform 4.3** — resources, DTO resources (Object Mapper), state providers, state processors, serialization, security, modern filters (`parameters` + `QueryParameter`), tests, versioning, pagination, performance, resilience, errors (RFC 7807 + `#[ErrorResource]`), identifiers (UUID v7 / ULID), OpenAPI + Scalar UI, MCP (@experimental), Mutators (`#[AsResourceMutator]` / `#[AsOperationMutator]`), user / password / `/me`, file upload (Vich + MediaObject), upgrade (3.x / 4.0-4.2 → 4.3).
- **24 Symfony 7.4+ core** — Messenger + retry strategies, scheduler, voters, rate limiting, cache, controller cleanup, interfaces + autowiring, ports & adapters (Deptrac), CQRS + handlers, value objects + DTOs, config / env / parameters, strategy pattern, Doctrine (relations, migrations, fixtures via Foundry, transactions, fetch modes, batch processing), TDD (Pest + PHPUnit), functional tests, test doubles, quality checks (PHP-CS-Fixer, PHPStan, Infection, `composer audit`, Renovate).
- **9 workflow** — entry point, runner selection (DDEV / Make / FrankenPHP / Compose / host, monorepo-aware), Makefile discipline, bootstrap check, daily workflow, effective context, brainstorming, writing plans, executing plans.

#### 7 specialized agents

| Agent | Stage | Mode | Role |
|---|---|---|---|
| `api-platform-architect` | Architecture | Read-only | 9-section plan + test matrix |
| `api-platform-aligned-reviewer` | Architecture (parallel) | Read-only | KISS push-back, preserve verbatim |
| `api-platform-appsec` | Architecture (parallel) | Read-only | OWASP findings, preserve verbatim |
| `api-platform-implementer` | Dev | Read/Write | Implements the plan, runs phpstan + phpunit + Infection |
| `symfony-tdd-coach` | Test | Read/Write | AC matrix, anti-tautology, kills mutants |
| `symfony-reviewer` | Review | Read-only | Gatekeeper with 24+ anti-patterns checklist, EVIDENCE block, skill-dispatch theatre detection |
| `doctrine-architect` | Utility | Read-only | Schema design, UUID v7 / ULID strategy, migration planning |

The 3 architecture personas are dispatched in parallel from `/architect`.

#### 25 slash commands

- **Pipeline (7)** — `/architect`, `/dev`, `/test`, `/review`, `/api-resource-pipeline` (semi-auto, REQUEST_CHANGES loop capped at 3), `/api-resource-ship` (full autonomy: branch + pipeline + commit + push + PR), `/self-audit-api`.
- **Atomic (18)** — `/symfony-api-resources`, `/symfony-api-filters`, `/symfony-api-mcp`, `/symfony-api-mutators`, `/symfony-api-errors`, `/symfony-api-upgrade`, `/symfony-voters`, `/symfony-messenger`, `/symfony-cache`, `/symfony-tdd-pest`, `/symfony-tdd-phpunit`, `/symfony-migrations`, `/symfony-fixtures`, `/symfony-doctrine-relations`, `/symfony-check`, `/brainstorm`, `/write-plan`, `/execute-plan`.

#### Session-start hook

Detects on session start:
- Symfony application (via `composer.json` + `symfony/framework-bundle`), including monorepos where Symfony lives in a sub-dir.
- API Platform package — 4.x split (`api-platform/symfony` + `api-platform/doctrine-orm`) and legacy `api-platform/core`.
- Symfony and API Platform versions (warns explicitly if `< 7.4` or `< 4.3` and points to `gerard:api-platform-upgrade`).
- Orchestration root (`Makefile` / `compose.yaml` / `.ddev/`) and runner type (DDEV / Make / FrankenPHP / Compose / host).
- Test framework (Pest / PHPUnit).
- Make targets (`make ci`, `make quality`, `make migrations`, etc.) for projects with a `Makefile` (including the `Makefile` vs `Makefile-solution` Smile-style split).

#### Pipeline state files

Stored under `.claude/last-api-*.md` (gitignored). One per stage:

| State file | Stage |
|---|---|
| `.claude/last-api-plan.md` | Architecture |
| `.claude/last-api-dev-report.md` | Dev |
| `.claude/last-api-test-report.md` | Test |
| `.claude/last-api-review.md` | Review |

Markers `===STAGE-BEGIN===` / `===STAGE-END===` (see [`docs/symfony/marker-protocol.md`](docs/symfony/marker-protocol.md)) make the sub-agent outputs deterministic to parse.

#### Project skills layer

Projects consuming the plugin can add `.claude/skills/<project>/*.md` to declare their **local doctrine** on top of the plugin canon. Naming convention `<project>:X` (e.g. `myapp:form-contract`) takes priority over `gerard:X` when both exist. See [`docs/symfony/project-skills-pattern.md`](docs/symfony/project-skills-pattern.md).

#### Anti-regression lint

`scripts/lint_skill_content.ts` rejects any pre-4.3 API Platform pattern outside of the dedicated `api-platform-upgrade` skill: `#[ApiFilter]`, `openapiContext`, `hydra:` prefix in serialized JSON-LD, `AbstractFilter` extension, `BooleanFilter` (legacy), `SerializerAwareProviderInterface`, `ApiPlatform\Symfony\Validator\Exception\ValidationException`, Symfony pre-7.4.

#### Forensic loop

Pattern "ship → measure → tighten persona with explicit forbids" documented in [`docs/symfony/forensic-audit-template.md`](docs/symfony/forensic-audit-template.md) — track post-merge corrections, identify the dominant persona, tighten its rules from observed cases, iterate.

### Supported versions

| Framework | Version | Status |
|---|---|---|
| API Platform | **4.3+** | Required |
| Symfony | **7.4 LTS** (released Nov 2025) | Required |
| Symfony | **8.0+** | Supported |
| PHP | **8.2+** | Required |

Older versions are out of scope. The session hook warns explicitly and points to `gerard:api-platform-upgrade` to migrate.

### Installation

```bash
/plugin marketplace add gerard-labs/superpowers-api-platform
/plugin install gerard@superpowers-api-platform
```

### Out of scope (intentionally not in scope)

- Orchestrator mode (`samurai-build` and similar full-autonomy daemons) — this plugin stays purely Claude-Code-host driven.
- API Platform versions < 4.3 — covered by `gerard:api-platform-upgrade` as a migration target, not as a supported runtime.
- Symfony versions < 7.4 — same rationale; older LTS lines are out of scope.

### License

MIT.
