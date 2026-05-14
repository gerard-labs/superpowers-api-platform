# gerard skills map

Full index of the 53 skills shipped by the v1.0 plugin. Each line points to where the deep content lives. The plugin targets **API Platform 4.3+** running on **Symfony 7.4 LTS+** exclusively.

> **See also**: [overview](docs/overview.md) (5-min read), [how-it-works](docs/how-it-works.md) (architecture), [agents](docs/agents.md) (3 agents), [hooks](docs/hooks.md) (5 hooks), [skills](docs/skills.md) (catalog by domain), [anti-patterns](docs/anti-patterns.md) (39-rule SoT).

## API Platform 4.3 (20)

### Foundations
- `gerard:api-platform-resources` — `#[ApiResource]`, operations, IRI-only relations, subresources (Link), content negotiation, LDP headers 4.3, legacy controllers (avoid).
- `gerard:api-platform-dto-resources` — Input/Output DTOs, Object Mapper 4.3 (`#[Map]`), BackedEnum, IRI-only payloads.
- `gerard:api-platform-state-providers` — Provider decoration via `#[Autowire]`, CollectionOperationInterface, header-versioned providers.
- `gerard:api-platform-state-processors` — Processor decoration, native Messenger modes (`messenger: 'input'`, HTTP 202), CQRS bus bridging.
- `gerard:api-platform-serialization` — Groups (`entity:operation`), MaxDepth, BackedEnum, `#[Context]`, Context Builder vs Mutator, `gen_id`, force-IRI.
- `gerard:api-platform-security` — Operation security, voters, property security, JWT (Lexik), OIDC, CORS, `throw_on_access_denied`.

### Modern filters & pagination
- `gerard:api-platform-filters` — `parameters: [QueryParameter]` pattern: Exact / PartialSearch (`caseSensitive`) / Iri (nested) / Uuid / Comparison (`ne`) / Sort (`nullsComparison`) / FreeTextQuery / Or / Exists / BackedEnum / Property (sparse) / SparseFieldset (JSON:API). Cast options, Parameter Providers (4.3), Doctrine SQLFilter for multi-tenant.
- `gerard:api-platform-pagination` — Page / partial / cursor (UUID v7 + ComparisonFilter). 4.x defaults (30 / page, no `hydra:` prefix). paginationMaximumItemsPerPage. Custom paginators.

### Operations & metadata
- `gerard:api-platform-versioning` — URI / DTO / header / additive-group, Sunset / Deprecation / Link headers, `openapi: new Model\Operation(deprecated: true)`.
- `gerard:api-platform-openapi` — `openapi: new Model\Operation(...)`, factory decorator, Scalar UI 4.3, ADR template.
- `gerard:api-platform-mutators` — `#[AsResourceMutator]` / `#[AsOperationMutator]` (build-time). Decision matrix vs Context Builder.
- `gerard:api-platform-identifiers` — UUID v7 / ULID, composite via Link, custom slug, UriVariableTransformer / IdentifiersExtractor decoration.
- `gerard:api-platform-errors` — RFC 7807, `#[ErrorResource]`, `exceptionToStatus`, custom Error Provider, status resolution order.

### Quality & operations
- `gerard:api-platform-tests` — `ApiTestCase`, DAMA, Foundry, ParaTest, schema assertions, JWT clients, scenario-based naming.
- `gerard:api-platform-performance` — `eager_loading.force_eager` trap, FrankenPHP worker, cache tags + Varnish PURGE, APCu metadata cache, DQL `NEW` projections.
- `gerard:api-platform-resilience` — Circuit Breaker, degraded mode (`_notice`), async writes (HTTP 202 + Messenger + Workflow), exponential backoff + DLQ.

### Auth & uploads
- `gerard:api-platform-user` — User entity (UserInterface, PasswordAuthenticatedUserInterface), UserPasswordHasher Processor, PasswordUpgraderInterface, `/me` provider.
- `gerard:api-platform-file-upload` — VichUploaderBundle, multipart on Post only, MediaObject, contentUrl normalizer, Vich-Flysystem, ClamAV.

### AI integration
- `gerard:api-platform-mcp` — Model Context Protocol (@experimental). `#[McpTool]`, `McpToolCollection`, schema override for picky LLMs, dedicated rate limit + audit log.

### Migration
- `gerard:api-platform-upgrade` — Migration 3.x / 4.0–4.2 → 4.3. Only skill where legacy patterns are documented (Rector + PHPStan rule + Deptrac tooling).

## Symfony 7.4+ core (23)

### Messaging & async
- `gerard:symfony-messenger` — Async handling, transports, middleware.
- `gerard:messenger-retry-failures` — Retry strategies, DLQ, exponential backoff.
- `gerard:symfony-scheduler` — Recurring tasks via Messenger.

### Security
- `gerard:symfony-voters` — Voter pattern, isolated PHPUnit tests, attribute constants.
- `gerard:rate-limiting` — Sliding/fixed window/token bucket, API Platform Provider decorator pattern.

### Doctrine ORM
- `gerard:doctrine-relations` — Entity relationships, cascade, orphan removal.
- `gerard:doctrine-migrations` — Schema versioning, zero-downtime migrations.
- `gerard:doctrine-fixtures-foundry` — Factory pattern, states, sequences.
- `gerard:doctrine-transactions` — UnitOfWork, optimistic locking.
- `gerard:doctrine-fetch-modes` — Lazy / extra lazy / partial fetch, `force_eager` trap (4.x).
- `gerard:doctrine-batch-processing` — `toIterable()` + `clear()` for million-row volumes.

### Quality
- `gerard:quality-checks` — PHP-CS-Fixer, PHPStan level 9+, ParaTest, Infection (MSI ≥ 80 / covered-MSI ≥ 85), `composer audit`, Renovate, CI workflow.
- `gerard:symfony-cache` — Cache pools, tags, HTTP cache, APCu metadata cache, cache tags + Varnish PURGE.
- `gerard:controller-cleanup` — Thin controllers.
- `gerard:config-env-parameters` — `.env`, secrets, parameters.

### Architecture
- `gerard:interfaces-and-autowiring` — DI, binding, decoration, tagged services.
- `gerard:ports-and-adapters` — Hexagonal + bounded contexts + Deptrac + ADR as PHPStan rules.
- `gerard:cqrs-and-handlers` — Command/Query separation with Messenger, native API Platform Messenger mode, Domain Events vs Messenger.
- `gerard:value-objects-and-dtos` — Immutable VOs, BackedEnum, IRI-only DTO relations, Object Mapper alternative.
- `gerard:strategy-pattern` — Tagged services pattern.

### Testing
- `gerard:tdd-php` — RED-GREEN-REFACTOR with Pest or PHPUnit (fusion of tdd-with-pest + tdd-with-phpunit, framework chosen per session via `test_framework` from session-start hook).
- `gerard:functional-tests` — WebTestCase for non-API (forms, redirects, CSRF, flash messages).
- `gerard:test-doubles-mocking` — Mocks, fakes, in-memory adapters.

## Workflow (8)

- `gerard:using-symfony-superpowers` — Entry point + command map.
- `gerard:runner-selection` — Docker / DDEV / FrankenPHP / Make / host detection.
- `gerard:makefile-discipline` — `Makefile` (boilerplate, read-only) vs `Makefile-solution` (project-owned) split, `$(MAKEFILE_LIST)` help aggregation, `##@ Group` conventions, Docker wrappers, anti-patterns that get wiped at boilerplate bump.
- `gerard:daily-workflow` — Day-to-day patterns (absorbs the former bootstrap-check skill — project verification is now step 0 of the daily flow).
- `gerard:effective-context` — Context management for AI sessions.
- `gerard:brainstorming` — Structured brainstorming.
- `gerard:writing-plans` — Implementation plans.
- `gerard:executing-plans` — Checkpointed execution.

## Cross-cutting (2)

Skills consumed by other skills, agents, or hooks rather than tied to a single API Platform surface. They live at the top level of `skills/` like all others — Claude Code's plugin loader does not recurse, so a "meta/" sub-namespace would be invisible.

- `gerard:anti-patterns-audit` — Standalone audit of the current diff against API Platform 4.3 + Symfony 7.4+ anti-patterns. Returns a Y/N checklist with `file:line` evidence. **Source of truth** for the 24 base rules. Invoked by `api-implementer` (Step 5 self-audit), `gerard-gatekeeper` (full 39-rule pass), `hooks/post-tool-use.sh` (7-regex fast feedback), and standalone by devs. See [`docs/anti-patterns.md`](docs/anti-patterns.md) for the user-facing narrative.
- `gerard:goal-patterns` — Templates for the `/goal` condition. 8 story-shape addenda (feature / refactor / migration / hardening / bugfix / perf / docs / appsec) + a generic fallback = 9 patterns total. Used by the `/api` command to compose the `/goal` condition based on the detected story shape. See [`docs/goal-patterns.md`](docs/goal-patterns.md).
