---
name: api-platform-openapi
description: Customize API Platform 4.3 OpenAPI / Hydra / Scalar documentation — the `openapi: new \\ApiPlatform\\OpenApi\\Model\\Operation(...)` attribute (with `Info`, `Parameter`, `RequestBody`, `Response`, `Server`, `Contact`, `License`), decorating `api_platform.openapi.factory` to inject `x-logo` and global metadata, the `openapi: false` flag to hide an operation, custom OpenAPI parameters with `OpenApiParameter`, vendor extensions `x-*`, Scalar UI (`/api/docs?ui=scalar`, `enable_scalar`), Swagger UI / ReDoc, exporting the spec (`php bin/console api:openapi:export --yaml --spec-version=3.0.0 --filter-tags=public --api-gateway`), security schemes (`bearerAuth`), and ADR documentation in `docs/adr/`. **No `openapiContext`** — that belongs to `api-platform-upgrade`.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
effort:
  low: SKILL.md only — "Use when" + default workflow + key bullets.
  high: SKILL.md + reference.md — full doctrine.
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-openapi/) + edge cases.
---

# API Platform 4.3 — OpenAPI / Hydra / Scalar

## Use when
- Adding `openapi: new Model\Operation(...)` to an operation (summary, description, tags, requestBody, responses).
- Decorating the OpenAPI factory to inject corporate `Info` / `x-logo` / `Server`.
- Enabling Scalar UI on top of the default Swagger UI.
- Hiding internal operations from the doc (`openapi: false`).
- Marking operations as deprecated (`Model\Operation(deprecated: true)`).
- Exporting the spec for an API Gateway or partner.

## Default workflow
1. Set global OpenAPI metadata via a factory decorator (`#[AsDecorator(decorates: 'api_platform.openapi.factory')]`).
2. Per operation, attach `openapi: new Model\Operation(summary, description, tags, requestBody, responses)`.
3. For partner-facing endpoints, choose the UI: Swagger (default), ReDoc, Scalar (`?ui=scalar`).
4. Export and review the spec (`php bin/console api:openapi:export --yaml`).
5. Document architectural decisions in `docs/adr/` (ADR-XXXX.md).

## Guardrails
- **No `openapiContext`** — it is deprecated. Use `openapi: new Model\Operation(...)`.
- **Security in OpenAPI**: align `Model\Operation(security: [['bearerAuth' => []]])` with the global `swagger.api_keys` config.
- **Tags consistency**: pick a short list (`['Books', 'Public']`) and apply it everywhere.
- **Schemas vs groups**: every group affects the OpenAPI schema — use `openapi_definition_name` to disambiguate when needed.

## Progressive disclosure
- `SKILL.md` lists posture and rules.
- `reference.md` carries the full attribute usage, the factory decorator, `Info` / `Server` / `Contact` / `License`, custom `OpenApiParameter`, vendor extensions, Scalar configuration, export commands, security schemes, ADR template.

## Output contract
- Operations carry `openapi: new Model\Operation(...)` (never `openapiContext`).
- A factory decorator publishes corporate metadata.
- Spec exports validated (`api:openapi:export`).
- ADRs in `docs/adr/` document non-trivial decisions.

## References
- `reference.md`
