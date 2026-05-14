---
name: api-platform-identifiers
description: Choose and wire up API Platform 4.3 resource identifiers — UUID v7 (recommended for temporal cursor pagination), ULID, scalar (string/int), `\DateTimeInterface`, composite identifiers via `Link(uriVariables: …)`, custom identifiers (slug) with `#[ApiProperty(identifier: true)]`, decorating `UriVariableTransformerInterface` to coerce strings into typed objects (Uuid, custom), decorating `IdentifiersExtractorInterface` to format identifiers in responses (ISO date, custom). Trigger when modeling a new resource, switching from auto-increment ID to UUID v7 / ULID for anti-enumeration, supporting cursor-based pagination on a chronological field, or exposing a slug as the public identifier.
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
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-identifiers/) + edge cases.
---

# API Platform 4.3 — Identifiers (UUID v7, ULID, composite, custom)

## Use when
- Designing a new resource: should the identifier be a sequential int, a UUID, a ULID, or a slug?
- Switching an existing resource from auto-increment to UUID v7 (anti-enumeration + cursor pagination).
- Modeling a composite identifier (`/customer/{customerId}/order/{orderId}`).
- Exposing a slug as the public identifier while keeping an internal numeric ID.
- Customizing how an identifier is parsed from the URI or rendered in the response.

## Default workflow
1. Default to **UUID v7** (`Symfony\Component\Uid\Uuid::v7()`) on public resources — chronologically sortable + non-enumerable.
2. Annotate the identifier with `#[ApiProperty(identifier: true)]` and persist it as a native `uuid` column (PostgreSQL) or as a `ulid` column.
3. For composite identifiers, declare them in `uriVariables` with `Link(fromClass: …, identifiers: ['id'])`.
4. For custom identifiers (slug), set `#[ApiProperty(identifier: true)]` on the slug and `#[ApiProperty(identifier: false)]` on the auto-increment `id`.
5. Decorate `UriVariableTransformerInterface` only when the string-to-typed-object conversion is non-trivial.

## Guardrails
- **No sequential auto-increment IDs on public resources.** Volume leakage + enumeration.
- **UUID v7 > UUID v4** for any resource where chronological ordering helps (cursor pagination, B-tree indexing).
- **Native DB column types**: `uuid` (PostgreSQL) instead of `varchar(36)` — better indexing, smaller storage.
- **Composite identifiers** must be **stable** — never reuse a (customerId, orderId) pair.

## Progressive disclosure
- `SKILL.md` covers the decision tree.
- `reference.md` carries the full catalog (supported types), UUID v7 + cursor pagination wiring, composite identifiers with `Link`, custom slug pattern, `UriVariableTransformerInterface` and `IdentifiersExtractorInterface` recipes.

## Output contract
- Public resources use UUID v7 / ULID / slug — no exposed auto-increment.
- Composite identifiers declared via `Link(uriVariables: …, identifiers: […])`.
- DB columns use native types where supported.
- Tests assert the IRI shape (UUID format, slug format) instead of integer matching.

## References
- `reference.md`
