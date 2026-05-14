# gerard skills map (lite)

Lightweight index of the 53 skills. The plugin targets **API Platform 4.3+** on **Symfony 7.4 LTS+** exclusively.

> The pipeline commands `/api-resource-pipeline` and `/api-resource-ship` chain the 4 stages with 7 agents. See [`docs/symfony/pipeline-overview.md`](docs/symfony/pipeline-overview.md).

## API Platform 4.3 (20)

- `gerard:api-platform-resources` — `#[ApiResource]`, operations, IRI-only, subresources, LDP headers 4.3
- `gerard:api-platform-dto-resources` — Input/Output DTOs + Object Mapper 4.3 (`#[Map]`)
- `gerard:api-platform-state-providers` — Provider decoration via `#[Autowire]`
- `gerard:api-platform-state-processors` — Processor decoration, native Messenger modes, CQRS bus
- `gerard:api-platform-serialization` — Groups, MaxDepth, BackedEnum, `#[Context]`, Context Builder vs Mutator
- `gerard:api-platform-security` — Operation/property security, voters, JWT, OIDC, CORS
- `gerard:api-platform-filters` — `parameters: [QueryParameter]` (Exact / Partial / Iri / Uuid / Comparison / Sort / FreeText / Or / Exists / BackedEnum / Property), cast options, Parameter Providers
- `gerard:api-platform-pagination` — Page / partial / cursor (UUID v7), 4.x defaults (30/page, no `hydra:`)
- `gerard:api-platform-versioning` — URI / DTO / header / additive-group, Sunset headers
- `gerard:api-platform-openapi` — `openapi: new Model\Operation`, factory decorator, Scalar UI 4.3, ADR
- `gerard:api-platform-mutators` — `#[AsResourceMutator]` / `#[AsOperationMutator]` (build-time)
- `gerard:api-platform-identifiers` — UUID v7 / ULID, composite, custom slug
- `gerard:api-platform-errors` — RFC 7807, `#[ErrorResource]`, `exceptionToStatus`
- `gerard:api-platform-tests` — `ApiTestCase` + DAMA + Foundry + ParaTest, schema assertions
- `gerard:api-platform-performance` — `force_eager` trap, FrankenPHP worker, cache tags, APCu
- `gerard:api-platform-resilience` — Circuit Breaker, degraded mode, async writes, retry + DLQ
- `gerard:api-platform-user` — User entity, password hashing Processor, `/me` provider
- `gerard:api-platform-file-upload` — VichUploaderBundle, multipart, MediaObject
- `gerard:api-platform-mcp` — Model Context Protocol (@experimental), `#[McpTool]`
- `gerard:api-platform-upgrade` — 3.x / 4.0–4.2 → 4.3 migration guide (legacy patterns documented here)

## Symfony 7.4+ core (24)

### Messaging & async
- `gerard:symfony-messenger` — Async handling, transports, middleware
- `gerard:messenger-retry-failures` — Retry strategies, DLQ
- `gerard:symfony-scheduler` — Recurring tasks

### Security
- `gerard:symfony-voters` — Object-level authorization
- `gerard:rate-limiting` — Sliding / token bucket + Provider decorator

### Doctrine
- `gerard:doctrine-relations` — Entity relationships
- `gerard:doctrine-migrations` — Schema versioning
- `gerard:doctrine-fixtures-foundry` — Factory pattern
- `gerard:doctrine-transactions` — UnitOfWork, optimistic locking
- `gerard:doctrine-fetch-modes` — Lazy / extra lazy / partial, force_eager trap
- `gerard:doctrine-batch-processing` — `toIterable()` + `clear()`

### Quality & cache
- `gerard:quality-checks` — PHP-CS-Fixer, PHPStan, ParaTest, Infection (MSI ≥ 80), `composer audit`, Renovate
- `gerard:symfony-cache` — Pools, tags, HTTP cache, APCu
- `gerard:controller-cleanup` — Thin controllers
- `gerard:config-env-parameters` — `.env`, secrets, parameters

### Architecture
- `gerard:interfaces-and-autowiring` — DI, decoration, tagged services
- `gerard:ports-and-adapters` — Hexagonal + bounded contexts + Deptrac
- `gerard:cqrs-and-handlers` — Command/Query separation
- `gerard:value-objects-and-dtos` — Immutable VOs, BackedEnum
- `gerard:strategy-pattern` — Tagged services pattern

### Testing
- `gerard:tdd-with-pest` — TDD with Pest
- `gerard:tdd-with-phpunit` — TDD with PHPUnit
- `gerard:functional-tests` — WebTestCase for non-API
- `gerard:test-doubles-mocking` — Mocks, fakes

## Workflow (9)
- `gerard:using-symfony-superpowers`
- `gerard:runner-selection` — Docker / DDEV / FrankenPHP / Make / host detection
- `gerard:makefile-discipline` — `Makefile` vs `Makefile-solution` split, boilerplate-safe target conventions
- `gerard:bootstrap-check`
- `gerard:daily-workflow`
- `gerard:effective-context`
- `gerard:brainstorming`
- `gerard:writing-plans`
- `gerard:executing-plans`
