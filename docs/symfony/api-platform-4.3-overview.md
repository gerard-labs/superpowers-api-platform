# API Platform 4.3 — Overview

> A high-level navigation map for the API Platform 4.3 features covered by this plugin. Each section points to the dedicated skill that documents it in depth.

## Resource & operation modeling

- **Resource ≠ Entity** principle, explicit operations (`Get`, `GetCollection`, `Post`, `Put`, `Patch`, `Delete`), subresources via `Link(fromClass:, toProperty:)`, `itemUriTemplate` for nested-route consistency, IRI-only relations.
- Skill: [`gerard:api-platform-resources`](../../skills/api-platform-resources/SKILL.md).

## DTOs & Object Mapper

- Input / Output DTOs (`final readonly`), `BackedEnum` for statuses, IRI-only relations in payloads.
- 🆕 **Object Mapper 4.3** — `composer require symfony/object-mapper` + `#[Map(source: …)]` for mechanical DTO ↔ Entity mapping with zero Provider/Processor boilerplate.
- Skill: [`gerard:api-platform-dto-resources`](../../skills/api-platform-dto-resources/SKILL.md).

## State Providers & Processors

- Provider decorates `api_platform.doctrine.orm.state.item_provider` / `collection_provider` via `#[Autowire(service: …)]`.
- Processor decorates `api_platform.doctrine.orm.state.persist_processor` / `remove_processor`.
- Native Messenger mode on operations: `messenger: 'input'`, `output: false`, `status: 202`.
- Skills: [`gerard:api-platform-state-providers`](../../skills/api-platform-state-providers/SKILL.md), [`gerard:api-platform-state-processors`](../../skills/api-platform-state-processors/SKILL.md).

## Filters — modern 4.3 pattern

- `parameters: [...]` + `new QueryParameter(filter: new ExactFilter(), property: 'sku')` — **never** `#[ApiFilter]` or `AbstractFilter`.
- New filter classes: `ExactFilter`, `PartialSearchFilter` (with `caseSensitive: true`), `IriFilter` (nested), `UuidFilter`, `ComparisonFilter` (`gt`/`gte`/`lt`/`lte`/`ne`), `SortFilter` (`nullsComparison`), `FreeTextQueryFilter`, `OrFilter`, `BackedEnumFilter`, `PropertyFilter` (sparse, native), `SparseFieldset` (JSON:API).
- `property` is **mandatory** on Exact / Iri / Partial / Uuid.
- Cast options: `castToNativeType`, `castToArray`, `castFn`.
- Parameter Providers (4.3): `IriConverterParameterProvider`, `ReadLinkParameterProvider`, custom.
- Skill: [`gerard:api-platform-filters`](../../skills/api-platform-filters/SKILL.md).

## Serialization

- `entity:operation` group convention, force IRIs with `#[ApiProperty(readableLink: false, writableLink: false)]`, `MaxDepth`, `#[Context]` per-property, `gen_id`, `skip_null_values` (default 4.x), Context Builder vs Mutator decision.
- Skill: [`gerard:api-platform-serialization`](../../skills/api-platform-serialization/SKILL.md).

## Security

- Operation-level `security:`, `securityPostDenormalize` with `previous_object`, `extraProperties: ['throw_on_access_denied' => true]`.
- 4.3 perf: `isGranted` evaluated before the state provider when the expression does not reference `object`.
- Property-level via `#[ApiProperty(security: …)]`, voters, query collection extensions.
- JWT (Lexik) end-to-end (keys, security.yaml, refresh tokens, HttpOnly cookies, RS256), OIDC alternative, CORS via nelmio/cors-bundle, UUID v7 / ULID identifiers.
- Skill: [`gerard:api-platform-security`](../../skills/api-platform-security/SKILL.md).

## Tests

- `ApiTestCase` + Foundry + DAMA + ParaTest, schema assertions (`assertMatchesResourceItemJsonSchema`), JWT clients, `disableReboot()` for multi-request flows, scenario-based naming, default page size 30 (not 20), no `hydra:` prefix.
- Skill: [`gerard:api-platform-tests`](../../skills/api-platform-tests/SKILL.md).

## Versioning

- URI (`/v1/`, `/v2/`) for breaking changes, DTO per version, header `X-API-Version`, additive group for minor adds. `deprecationReason` + `sunset` + `openapi: new Model\Operation(deprecated: true)` (never `openapiContext`).
- Skill: [`gerard:api-platform-versioning`](../../skills/api-platform-versioning/SKILL.md).

## Pagination

- 4.x defaults: 30 items / page, no `hydra:` prefix. `paginationPartial: true` to skip COUNT. Cursor pagination with UUID v7 / ULID + `paginationViaCursor` + `ComparisonFilter` + `UuidFilter`.
- Skill: [`gerard:api-platform-pagination`](../../skills/api-platform-pagination/SKILL.md).

## Performance

- `eager_loading.force_eager: true` trap (4.x default — switch to `false`). Targeted join fetches. DTO projection (DQL `NEW`). Batch iteration (`toIterable()` + `clear()`). APCu metadata cache. FrankenPHP worker mode. `cacheHeaders` + `cacheTags` + Varnish PURGE.
- Skill: [`gerard:api-platform-performance`](../../skills/api-platform-performance/SKILL.md).

## Resilience

- Circuit Breaker (Closed / Open / Half-Open), degraded mode with `_notice.type: degraded_mode` in the response, async writes for slow upstreams (HTTP 202 + Messenger + Workflow), exponential backoff retry + DLQ.
- Skill: [`gerard:api-platform-resilience`](../../skills/api-platform-resilience/SKILL.md).

## Errors

- RFC 7807 default (`application/problem+json`). `#[ErrorResource]` + `ProblemExceptionInterface`. `exceptionToStatus` at config / resource / operation level. `errors: [...]` on operations (auto-documented in OpenAPI). Custom Error Provider.
- Skill: [`gerard:api-platform-errors`](../../skills/api-platform-errors/SKILL.md).

## Identifiers

- UUID v7 (`Uuid::v7()`) — chronological prefix ideal for cursor pagination. ULID alternative. Composite via `Link(uriVariables: …, identifiers: […])`. Custom slug. `UriVariableTransformerInterface` decoration. `IdentifiersExtractorInterface` decoration.
- Skill: [`gerard:api-platform-identifiers`](../../skills/api-platform-identifiers/SKILL.md).

## OpenAPI

- `openapi: new \ApiPlatform\OpenApi\Model\Operation(...)` (replaces `openapiContext`). Factory decorator on `api_platform.openapi.factory`. Swagger UI / ReDoc / **Scalar UI 4.3** (`?ui=scalar`). `api:openapi:export` commands. ADR template.
- Skill: [`gerard:api-platform-openapi`](../../skills/api-platform-openapi/SKILL.md).

## MCP (NEW 4.3 — `@experimental`)

- Expose operations as Model Context Protocol tools (`#[McpTool]`, `McpToolCollection`). HTTP-only or stdio transports. JSON Schema override for sensitive LLMs. Restricted tool set, dedicated rate limit, audit log.
- Skill: [`gerard:api-platform-mcp`](../../skills/api-platform-mcp/SKILL.md).

## Mutators (NEW 4.3)

- `#[AsResourceMutator]` / `#[AsOperationMutator]` for build-time metadata changes. Decision matrix vs Context Builder (build-time vs runtime).
- Skill: [`gerard:api-platform-mutators`](../../skills/api-platform-mutators/SKILL.md).

## User entity

- Canonical pattern: `UserInterface` + `PasswordAuthenticatedUserInterface`, `#[UniqueEntity('email')]`, `UserPasswordHasher` State Processor, repository implementing `PasswordUpgraderInterface`, `/me` via `CurrentUserProvider` (REST + GraphQL).
- Skill: [`gerard:api-platform-user`](../../skills/api-platform-user/SKILL.md).

## File upload

- VichUploaderBundle, multipart format enabled on `Post` only, `MediaObject` resource with `contentUrl` computed via `StorageInterface`, Vich-Flysystem for S3 / R2, ClamAV antivirus.
- Skill: [`gerard:api-platform-file-upload`](../../skills/api-platform-file-upload/SKILL.md).

## Upgrade (3.x / 4.0-4.2 → 4.3)

- Namespaces, package split (`api-platform/core` → `api-platform/symfony` + `api-platform/doctrine-orm`), default flips, `openapiContext` → `openapi: new Model\Operation()`, `#[ApiFilter]` → `parameters: [QueryParameter]`, deprecated interfaces. Rector + PHPStan custom rule + Deptrac tooling.
- Skill: [`gerard:api-platform-upgrade`](../../skills/api-platform-upgrade/SKILL.md).

## Configuration reference

- [`api-platform-config-4.3.md`](api-platform-config-4.3.md).

## Anti-pattern catalogue & PR review template

- [`api-platform-anti-patterns.md`](api-platform-anti-patterns.md).

## Skill index

- [`../../skills-map.md`](../../skills-map.md) — full index of the 53 `gerard:*` skills shipped by the plugin, grouped by domain (API Platform 4.3, Symfony 7.4+ core, workflow).
- [`../../skills-map-lite.md`](../../skills-map-lite.md) — one-liner per skill for quick scan.
