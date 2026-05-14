---
name: api-platform-versioning
description: Plan and implement API Platform 4.3 versioning — URI versioning (`/v1/`, `/v2/`), separate Output DTOs per version (with dedicated Providers), header-based versioning (`X-API-Version` resolved in a versioned Provider), additive group-based versioning for minor changes, deprecation with the 4.x attribute (`deprecationReason`, `sunset`, `openapi: new \\ApiPlatform\\OpenApi\\Model\\Operation(deprecated: true)`), `Sunset` / `Deprecation` / `Link` headers via a Response subscriber, and a per-version DTO changelog. Trigger when introducing a breaking change, planning a v2 endpoint, marking an operation as legacy, or migrating older versioning code from `openapiContext` (deprecated) to `openapi: new Model\\Operation`.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Versioning

## Use when
- Adding a new operation or resource that breaks the contract.
- Carving out a `/v2/` set of endpoints next to `/v1/`.
- Marking an operation deprecated with a Sunset date.
- Migrating older code that still uses `openapiContext: ['deprecated' => true]` (deprecated 4.x) to the modern attribute.

## Default workflow
1. Decide the strategy — URI versioning (breaking), Output DTOs per version (when payload shape diverges), header-based, or group additive (minor additions only).
2. Implement the chosen strategy with explicit `uriTemplate`, dedicated DTOs / Provider, or new group.
3. On retired operations: set `deprecationReason`, `sunset`, and `openapi: new Model\Operation(deprecated: true)`.
4. Add a `KernelEvents::RESPONSE` subscriber to emit `Sunset` / `Deprecation` / `Link: …; rel="successor-version"` headers.
5. Document the diff at the top of each new DTO (changelog comment).

## Guardrails
- **URI versioning for breaking changes.** Clearest signal for clients.
- **Group additive only for additions** — never to remove or rename.
- **Always announce a sunset date** when retiring an operation.
- **Limit active versions** — keep 2-3 at most. Beyond that, the maintenance burden explodes.
- **Test every active version** — no silent regression on v1.

## Progressive disclosure
- `SKILL.md` lists strategies and rules.
- `reference.md` carries full examples for each strategy, the `openapi` 4.x attribute (Rector migration script for `openapiContext`), Sunset / Deprecation / Link headers, the DTO changelog header, multi-version functional tests, and best practices.

## Output contract
- New resources / DTOs / Providers per version with explicit `uriTemplate`.
- Deprecated operations carry `deprecationReason`, `sunset`, and `openapi: new Model\Operation(deprecated: true)`.
- A response subscriber emits Sunset headers.
- Functional tests cover every active version.

## References
- `reference.md`
