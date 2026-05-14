# API Platform 4.3 — Anti-patterns & PR checklist

> PR review template for API Platform 4.3 — apply on every Resource PR and as a self-check before declaring a feature done.

## Anti-patterns — reject on sight

### Contract & serialization

- ❌ Expose every entity column without explicit `#[Groups]`.
- ❌ Reuse the same group for reads and writes.
- ❌ Missing `MaxDepth` on circular relations.
- ❌ Sensitive field (`password`, token, secret) exposed — even accidentally.
- ❌ Free `string` for a status / type / category — should be `BackedEnum`.
- ❌ Scalar identifiers in DTO payloads (`customerId: 42`) instead of IRIs (`customer: "/api/customers/01J…"`).

### Operations & routing

- ❌ Operations declared implicitly (relying on `#[ApiResource]` magic) — declare each one explicitly.
- ❌ Custom Symfony controller where a State Processor / Provider would do — Symfony controllers in API Platform are legacy.
- ❌ Versioning a breaking change via groups — must be a new URI.

### Security

- ❌ Hardcoded role checks in a Provider / Processor — use `security:` or a voter.
- ❌ Missing `security:` on a non-public operation.
- ❌ Missing `securityMessage` — leaks debug info or confuses users.
- ❌ `security` referencing `object` when it's not necessary — kills the 4.3 pre-provider perf gain.
- ❌ Sequential auto-increment IDs on public resources — use UUID v7 / ULID.
- ❌ `*` in CORS `allow_origin` with `allow_credentials: true`.

### Filters & queries

- ❌ **`#[ApiFilter]`** in new code (deprecated 4.2, removed 5.0).
- ❌ **`extends AbstractFilter`** in new code.
- ❌ Filter without an index on the targeted column.
- ❌ `PartialSearchFilter` on a column without a functional index on `LOWER(col)`.
- ❌ Filter missing the `property` argument in 4.3 (`InvalidArgumentException` at compile time).

### Persistence & performance

- ❌ `EAGER` at mapping level on a voluminous relation.
- ❌ `eager_loading.force_eager: true` (the 4.x default) on an entity with many relations — keep `false` + targeted join fetches.
- ❌ `EntityManager` injected into a Provider.
- ❌ N+1 queries (no join fetch in the repository, no Output DTO projection).

### Documentation & errors

- ❌ **`openapiContext:`** in new code — use `openapi: new \ApiPlatform\OpenApi\Model\Operation(...)`.
- ❌ **`NelmioApiDocBundle`** for a new project — use native OpenAPI + Scalar UI.
- ❌ Stack trace / file paths leaked in 500 responses in production.
- ❌ Business details in 401 / 403 responses (enumeration risk).

### Events & extension points

- ❌ Symfony listeners for business logic — use Providers / Processors (REST + GraphQL compatible).
- ❌ `use_symfony_listeners: true` enabled unnecessarily (perf cost).
- ❌ **`SerializerAwareProviderInterface`** / **`SerializableProvider`** in new code (deprecated 4.2, removed 5.0).

### Tests

- ❌ Only happy-path tests — every operation needs negative coverage (401, 403, 404, 422).
- ❌ `hydra:member` / `hydra:totalItems` assertions — 4.x default is `hydra_prefix: false`.
- ❌ Hard-coded default page size of 20 — it's 30 in 4.x.
- ❌ Missing schema assertions (`assertMatchesResourceItemJsonSchema`).

### MCP & AI integration (4.3)

- ❌ MCP enabled without dedicated rate limiting on `/mcp`.
- ❌ MCP exposing destructive operations (`Delete`) without an explicit confirmation flow.
- ❌ Missing audit log on MCP tool calls.

## PR review checklist

Tick every box before merging:

- ☐ Every operation is declared explicitly (`Get`, `GetCollection`, `Post`, `Put`, `Patch`, `Delete`).
- ☐ Read / write groups are separated and named `entity:operation` (e.g. `product:read`, `product:create`).
- ☐ `security:` is set on every non-public operation, with a clear `securityMessage`.
- ☐ Voters are used when the rule exceeds a single boolean clause.
- ☐ Validation lives on the Input DTO or the entity, with clear messages.
- ☐ `MaxDepth` is enabled on circular-risk relations.
- ☐ Sensitive fields are `#[Ignore]` or out of every group.
- ☐ Filters use the modern `parameters: [QueryParameter]` pattern. No `#[ApiFilter]` in new code.
- ☐ Filtered columns are indexed (Doctrine `#[ORM\Index]`).
- ☐ No N+1 — join fetch in repository or projected Output DTO via DQL `NEW`.
- ☐ Tests cover: happy path + 401 + 403 + 404 + 422 + filters + pagination + JSON schema.
- ☐ Default page size assertion = 30 (4.x), keys without `hydra:` prefix.
- ☐ OpenAPI exported (`php bin/console api:openapi:export --yaml`) and inspected.
- ☐ Versioning: DTO or groups, plus `deprecationReason` + `Sunset` if replacing a previous version.
- ☐ `openapi: new Model\Operation(...)` — never `openapiContext`.
- ☐ Rate limiting wired on sensitive endpoints, with `X-RateLimit-*` + `Retry-After` headers on 429.
- ☐ Provider / Processor stay thin — no business logic; delegate to a service or CQRS handler.
- ☐ Transactional integrity guaranteed on writes (`wrapInTransaction` or `doctrine_transaction` middleware).
- ☐ Identifiers: UUID v7 / ULID for public resources; sequential int only on internal-only entities.
- ☐ Errors: domain exceptions modeled as `#[ErrorResource]` (where applicable), `exceptionToStatus` mapping for the rest, RFC 7807 confirmed.
- ☐ MCP (if used): tools restricted, schema strict, audit log, dedicated rate limit, `@experimental` version pinned.
- ☐ Validation commands all pass: `debug:router`, `phpstan analyse`, `phpunit --filter=Api`, `api:openapi:export`, lint scripts.

## Linked tooling

- **Anti-regression lint** (`scripts/lint_skill_content.ts` in this plugin) — blocks legacy patterns from re-entering the codebase.
- **PHPStan custom rule** — encode ADRs as static checks (no `EntityManager` in Provider, command DTOs `final readonly`, Resource ≠ Entity).
- **Deptrac** — enforce bounded-context boundaries (cf. `gerard:ports-and-adapters`).
- **Rector + `lyrixx/rector-apip-openapi`** — bulk migration from `openapiContext` to `openapi: new Model\Operation()`.

## Related skills

- `gerard:api-platform-resources`
- `gerard:api-platform-filters`
- `gerard:api-platform-security`
- `gerard:api-platform-tests`
- `gerard:api-platform-upgrade`
- `gerard:quality-checks`
- `gerard:ports-and-adapters` (Deptrac, ADR as PHPStan rules)
