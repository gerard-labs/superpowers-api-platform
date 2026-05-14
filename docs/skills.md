# Skills

> 53 doctrinal skills organized by domain. Each skill ships at `skills/<name>/SKILL.md` (and optionally `skills/<name>/reference.md` for deep content). The plugin namespace `gerard:` is applied automatically by Claude Code from `.claude-plugin/plugin.json`.

## Index by domain

| Domain | Count | Section |
|---|---|---|
| API Platform 4.3 | 20 | [↓](#api-platform-43) |
| Doctrine ORM | 6 | [↓](#doctrine-orm) |
| Symfony 7.4+ core (async/security/cache) | 6 | [↓](#symfony-74-core) |
| Architecture patterns | 7 | [↓](#architecture-patterns) |
| Testing & quality | 4 | [↓](#testing--quality) |
| Workflow | 8 | [↓](#workflow) |
| Meta (cross-cutting) | 2 | [↓](#meta-cross-cutting) |
| **Total** | **53** | |

---

## API Platform 4.3

### Foundations (6)

| Skill | Scope |
|---|---|
| [`gerard:api-platform-resources`](../skills/api-platform-resources/SKILL.md) | `#[ApiResource]`, operations, IRI-only relations, subresources (Link), content negotiation, LDP headers 4.3, legacy controllers (avoid). |
| [`gerard:api-platform-dto-resources`](../skills/api-platform-dto-resources/SKILL.md) | Input/Output DTOs, **Object Mapper 4.3** (`#[Map]`), BackedEnum, IRI-only payloads. |
| [`gerard:api-platform-state-providers`](../skills/api-platform-state-providers/SKILL.md) | Provider decoration via `#[Autowire]`, CollectionOperationInterface, header-versioned providers. |
| [`gerard:api-platform-state-processors`](../skills/api-platform-state-processors/SKILL.md) | Processor decoration, native Messenger modes (`messenger: 'input'`, HTTP 202), CQRS bus bridging. |
| [`gerard:api-platform-serialization`](../skills/api-platform-serialization/SKILL.md) | Groups (`entity:operation`), MaxDepth, BackedEnum, `#[Context]`, Context Builder vs Mutator, `gen_id`, force-IRI. |
| [`gerard:api-platform-security`](../skills/api-platform-security/SKILL.md) | Operation security, voters, property security, JWT (Lexik), OIDC, CORS, `throw_on_access_denied`. |

### Modern filters & pagination (2)

| Skill | Scope |
|---|---|
| [`gerard:api-platform-filters`](../skills/api-platform-filters/SKILL.md) | `parameters: [QueryParameter]` pattern : Exact / PartialSearch (`caseSensitive`) / Iri (nested) / Uuid / Comparison (`ne`) / Sort (`nullsComparison`) / FreeTextQuery / Or / Exists / BackedEnum / Property (sparse) / SparseFieldset. Cast options. Parameter Providers (4.3). Doctrine SQLFilter for multi-tenant. |
| [`gerard:api-platform-pagination`](../skills/api-platform-pagination/SKILL.md) | Page / partial / cursor (UUID v7 + ComparisonFilter). 4.x defaults (30 / page, no `hydra:` prefix). `paginationMaximumItemsPerPage`. Custom paginators. |

### Operations & metadata (5)

| Skill | Scope |
|---|---|
| [`gerard:api-platform-versioning`](../skills/api-platform-versioning/SKILL.md) | URI / DTO / header / additive-group, Sunset / Deprecation / Link headers, `openapi: new Model\Operation(deprecated: true)`. |
| [`gerard:api-platform-openapi`](../skills/api-platform-openapi/SKILL.md) | `openapi: new Model\Operation(...)`, factory decorator, **Scalar UI 4.3**, ADR template. |
| [`gerard:api-platform-mutators`](../skills/api-platform-mutators/SKILL.md) | `#[AsResourceMutator]` / `#[AsOperationMutator]` (build-time). Decision matrix vs Context Builder. |
| [`gerard:api-platform-identifiers`](../skills/api-platform-identifiers/SKILL.md) | UUID v7 / ULID, composite via Link, custom slug, `UriVariableTransformer` / `IdentifiersExtractor` decoration. |
| [`gerard:api-platform-errors`](../skills/api-platform-errors/SKILL.md) | RFC 7807, `#[ErrorResource]`, `exceptionToStatus`, custom Error Provider, status resolution order. |

### Quality & operations (3)

| Skill | Scope |
|---|---|
| [`gerard:api-platform-tests`](../skills/api-platform-tests/SKILL.md) | `ApiTestCase`, DAMA, Foundry, ParaTest, schema assertions, JWT clients, scenario-based naming. |
| [`gerard:api-platform-performance`](../skills/api-platform-performance/SKILL.md) | `eager_loading.force_eager` trap, FrankenPHP worker, cache tags + Varnish PURGE, APCu metadata cache, DQL `NEW` projections. |
| [`gerard:api-platform-resilience`](../skills/api-platform-resilience/SKILL.md) | Circuit breaker, degraded mode (`_notice`), async writes (HTTP 202 + Messenger + Workflow), exponential backoff + DLQ. |

### Auth, uploads, AI, migration (4)

| Skill | Scope |
|---|---|
| [`gerard:api-platform-user`](../skills/api-platform-user/SKILL.md) | User entity (`UserInterface`, `PasswordAuthenticatedUserInterface`), `UserPasswordHasher` Processor, `PasswordUpgraderInterface`, `/me` provider. |
| [`gerard:api-platform-file-upload`](../skills/api-platform-file-upload/SKILL.md) | VichUploaderBundle, multipart on Post only, `MediaObject`, `contentUrl` normalizer, Vich-Flysystem, ClamAV. |
| [`gerard:api-platform-mcp`](../skills/api-platform-mcp/SKILL.md) | **Model Context Protocol** (@experimental). `#[McpTool]`, `McpToolCollection`, schema override for picky LLMs, dedicated rate limit + audit log. |
| [`gerard:api-platform-upgrade`](../skills/api-platform-upgrade/SKILL.md) | Migration 3.x / 4.0–4.2 → 4.3. **Only** skill where legacy patterns are documented (Rector + PHPStan rule + Deptrac tooling). |

---

## Doctrine ORM

| Skill | Scope |
|---|---|
| [`gerard:doctrine-relations`](../skills/doctrine-relations/SKILL.md) | Entity relationships, cascade, orphan removal, fetch modes. |
| [`gerard:doctrine-migrations`](../skills/doctrine-migrations/SKILL.md) | Schema versioning, zero-downtime patterns. |
| [`gerard:doctrine-fixtures-foundry`](../skills/doctrine-fixtures-foundry/SKILL.md) | Foundry factory pattern, states, sequences, story fixtures. |
| [`gerard:doctrine-transactions`](../skills/doctrine-transactions/SKILL.md) | UnitOfWork, optimistic locking, flush strategies. |
| [`gerard:doctrine-fetch-modes`](../skills/doctrine-fetch-modes/SKILL.md) | Lazy / extra lazy / partial fetch, `force_eager` trap (4.x), query hints. |
| [`gerard:doctrine-batch-processing`](../skills/doctrine-batch-processing/SKILL.md) | `toIterable()` + `clear()` for million-row volumes. |

---

## Symfony 7.4+ core

### Async & scheduling (3)

| Skill | Scope |
|---|---|
| [`gerard:symfony-messenger`](../skills/symfony-messenger/SKILL.md) | Async handling, transports, middleware, native API Platform Messenger mode. |
| [`gerard:messenger-retry-failures`](../skills/messenger-retry-failures/SKILL.md) | Retry strategies, DLQ, exponential backoff. |
| [`gerard:symfony-scheduler`](../skills/symfony-scheduler/SKILL.md) | Recurring tasks via Messenger schedule triggers. |

### Security & rate limiting (2)

| Skill | Scope |
|---|---|
| [`gerard:symfony-voters`](../skills/symfony-voters/SKILL.md) | Voter pattern, isolated PHPUnit tests, attribute constants. |
| [`gerard:rate-limiting`](../skills/rate-limiting/SKILL.md) | Sliding / fixed window / token bucket, API Platform Provider decorator pattern. |

### Cache (1)

| Skill | Scope |
|---|---|
| [`gerard:symfony-cache`](../skills/symfony-cache/SKILL.md) | Cache pools, tags, HTTP cache, APCu metadata cache, cache tags + Varnish PURGE. |

---

## Architecture patterns

| Skill | Scope |
|---|---|
| [`gerard:controller-cleanup`](../skills/controller-cleanup/SKILL.md) | Thin controllers, delegating to services / processors. |
| [`gerard:interfaces-and-autowiring`](../skills/interfaces-and-autowiring/SKILL.md) | DI, binding, decoration, tagged services. |
| [`gerard:ports-and-adapters`](../skills/ports-and-adapters/SKILL.md) | Hexagonal + bounded contexts + Deptrac + ADR as PHPStan rules. |
| [`gerard:cqrs-and-handlers`](../skills/cqrs-and-handlers/SKILL.md) | Command / Query separation with Messenger, native API Platform Messenger mode, Domain Events vs Messenger. |
| [`gerard:value-objects-and-dtos`](../skills/value-objects-and-dtos/SKILL.md) | Immutable VOs, BackedEnum, IRI-only DTO relations, Object Mapper alternative. |
| [`gerard:strategy-pattern`](../skills/strategy-pattern/SKILL.md) | Tagged services for runtime algorithm selection. |
| [`gerard:config-env-parameters`](../skills/config-env-parameters/SKILL.md) | `.env`, secrets, parameters, env-specific config. |

---

## Testing & quality

| Skill | Scope |
|---|---|
| [`gerard:tdd-php`](../skills/tdd-php/SKILL.md) | RED-GREEN-REFACTOR — **fusion of Pest + PHPUnit** with routing via `test_framework` from session-start. Two inline squelettes per framework, shared sections (DAMA, Foundry, ParaTest, Infection, anti-tautology). |
| [`gerard:functional-tests`](../skills/functional-tests/SKILL.md) | WebTestCase for non-API (forms, redirects, CSRF, flash messages). |
| [`gerard:test-doubles-mocking`](../skills/test-doubles-mocking/SKILL.md) | Mocks, fakes, in-memory adapters. |
| [`gerard:quality-checks`](../skills/quality-checks/SKILL.md) | PHP-CS-Fixer, PHPStan level 9+, ParaTest, Infection (MSI ≥ 80 / covered-MSI ≥ 85), `composer audit`, Renovate, CI workflow. |

---

## Workflow

| Skill | Scope |
|---|---|
| [`gerard:using-symfony-superpowers`](../skills/using-symfony-superpowers/SKILL.md) | Entry point and command map. |
| [`gerard:runner-selection`](../skills/runner-selection/SKILL.md) | Docker / DDEV / FrankenPHP / Make / host detection (monorepo-aware). |
| [`gerard:makefile-discipline`](../skills/makefile-discipline/SKILL.md) | `Makefile` (boilerplate, read-only) vs `Makefile-solution` (project-owned) split, `$(MAKEFILE_LIST)` help aggregation, `##@ Group` conventions, Docker wrappers, anti-patterns that get wiped at boilerplate bump. |
| [`gerard:daily-workflow`](../skills/daily-workflow/SKILL.md) | Day-to-day patterns, project verification (absorbs the v0.1 `bootstrap-check`), debugging, productivity. |
| [`gerard:effective-context`](../skills/effective-context/SKILL.md) | Context management for AI sessions. |
| [`gerard:brainstorming`](../skills/brainstorming/SKILL.md) | Structured brainstorming. |
| [`gerard:writing-plans`](../skills/writing-plans/SKILL.md) | Implementation plans (hors pipeline / for non-`/api` work). |
| [`gerard:executing-plans`](../skills/executing-plans/SKILL.md) | Checkpointed execution. |

---

## Meta (cross-cutting)

| Skill | Scope |
|---|---|
| [`gerard:meta/anti-patterns-audit`](../skills/meta/anti-patterns-audit/SKILL.md) | Standalone audit of the current diff against the 24-rule checklist (16 AP 4.3 + 8 Symfony 7.4+). Invocable from gatekeeper, implementer self-audit, or directly. Step 1 collect surface, step 2 7-regex fast pass, step 3 Y/N structured checklist with evidence, step 4 project-overrides cross-check (xhigh only), step 5 markdown output. |
| [`gerard:meta/goal-patterns`](../skills/meta/goal-patterns/SKILL.md) | `/goal` condition templates : base 4 bullets + 8 shape addenda (new-resource, new-operation, new-filter, new-state-flow, migration, bugfix, refactor, security-hardening) + generic. Consumed by `commands/api.md` step 4. |

---

## Effort-routing

20 skills in the **API Platform 4.3** domain plus `tdd-php` and both `meta/*` skills declare an `effort:` block in their frontmatter :

```yaml
effort:
  low:   SKILL.md only — "Use when" + default workflow + key bullets.
  high:  SKILL.md + reference.md — full doctrine.
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/<skill>/) + edge cases.
```

`/api --effort low|high|xhigh` propagates the level to skill dispatch. Other skills (Doctrine, Symfony async, architecture, etc.) ship a single SKILL.md without variants — the routing block is unnecessary.

---

## Project overrides

A consuming project can ship `.claude/skills/<project-name>/<skill>/SKILL.md` to override the plugin canon for that skill. Naming convention : `<project>:X` takes priority over `gerard:X` when both exist.

Example use case : `myapp` runs on a fork of API Platform with custom filter classes. The project ships `.claude/skills/myapp/api-platform-filters/SKILL.md` documenting the local patterns. The implementer agent's authority order checks `Glob: .claude/skills/*/api-platform-filters/SKILL.md` before falling back to `gerard:api-platform-filters`.

---

## Validation

All skills are validated by `scripts/validate_skills.ts` :

```bash
npm install
rtk proxy npx tsx scripts/validate_skills.ts
```

The validator checks :
- Frontmatter shape (`name`, `description`, `allowed-tools` required ; `effort` optional)
- `name` matches the directory
- For sub-dirs under `skills/meta/` : recurses into each (namespace handling added in Session 5)
- All `allowed-tools` are valid tool names

`scripts/lint_skill_content.ts` adds content-level checks (e.g. no legacy 3.x patterns outside `api-platform-upgrade`).

---

## References

- [`agents.md`](agents.md) — which skills each agent declares
- [`anti-patterns.md`](anti-patterns.md) — the canonical 24-rule checklist (sourced from `meta/anti-patterns-audit`)
- [`goal-patterns.md`](goal-patterns.md) — the 9 templates (sourced from `meta/goal-patterns`)
- [`commands.md`](commands.md) — `/api --effort` flag
- [`v1.0-plan.md`](v1.0-plan.md) section 3c — the 53 → 50 → 53 consolidation story
