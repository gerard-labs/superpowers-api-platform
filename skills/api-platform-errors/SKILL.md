---
name: api-platform-errors
description: Design API Platform 4.3 error handling around RFC 7807 (`application/problem+json`, default in 4.x). Covers `exceptionToStatus` mapping at config / resource / operation level, the 4.3 `errors: [DomainException::class]` flag on operations (auto-documented in OpenAPI), `#[ErrorResource]` + `ProblemExceptionInterface` to turn domain exceptions into documented error resources, custom Error Provider via `#[AsAlias('api_platform.state.error_provider')]`, the HTTP status resolution order (`exceptionToStatus` → `HttpExceptionInterface` → `ProblemExceptionInterface` → defaults → 500), validation error provider (422 + `ConstraintViolationList`), input validation (`Assert\*` on the DTO Input or entity, `UniqueEntity`, validation groups via `validationContext`, custom `Constraint` + `ConstraintValidator`, `collectDenormalizationErrors`, `serialize_payload_fields` for debug, `ValidationException` 4.x namespace move), prod-safe error messages (`setDetail('An unexpected error occurred.')` for 500), stable error `type` URIs (versioned `/errors/v1/...`), and the safety rule of not leaking enumeration details in 401/403. Trigger on "model a domain exception", "RFC 7807", "Problem Detail", "exception to status", "404 vs 410 gone", "validation groups", "Assert constraint", "UniqueEntity", "422 ConstraintViolationList", or "hide error stack trace in prod".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Errors (RFC 7807, ErrorResource, custom Error Provider)

## Use when
- Designing a new domain exception and how it surfaces in the API.
- Mapping exception → status code globally or per operation.
- Hiding 500 stack traces in production while keeping meaningful 4xx errors.
- Adding `errors: [DomainException::class]` so OpenAPI documents the failure case.
- Customizing the error provider to enrich Problem Detail payloads (`type`, `title`, `instance`).

## Default workflow
1. Confirm `rfc_7807_compliant_errors: true` is set (default in 4.x — Problem Detail format).
2. For each domain exception, decide: `exceptionToStatus` mapping, `#[ErrorResource]` (documented + customizable), or rely on the default.
3. Add `errors: [...]` on relevant operations so OpenAPI documents the failure cases.
4. Implement a custom Error Provider only when you need to enrich the Problem payload (`setDetail`, `type`, `instance`).
5. Verify: 422 / 404 / 409 / 410 / 500 all round-trip with the correct `Content-Type: application/problem+json`.

## Guardrails
- **No stack traces / file paths in production.** A 500 always gets a generic `detail`.
- **No business details in 401 / 403.** Enumeration risk — generic "Access denied".
- **Stable `type` URIs.** Clients pattern-match on them — version them (`/errors/v1/stock-unavailable`).
- **`ValidationException` namespace**: in 4.x it lives at `ApiPlatform\Validator\Exception\ValidationException`. The legacy `ApiPlatform\Symfony\…` path is removed.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full config, `exceptionToStatus` levels, `#[ErrorResource]` template, custom Error Provider with `Error::createFromException`, status resolution order, validation error provider, prod-safe pattern, type versioning.

## Output contract
- Domain exceptions either mapped via `exceptionToStatus` or modeled as `#[ErrorResource]` with `ProblemExceptionInterface`.
- Operations declaring `errors: [...]` for documented failure modes.
- Tests asserting `application/problem+json` Content-Type and the exact `type` / `title` / `status` fields.
- Production environment configured to hide stack traces.

## References
- `reference.md`
