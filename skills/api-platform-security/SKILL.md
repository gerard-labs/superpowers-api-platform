---
name: api-platform-security
description: Secure an API Platform 4.3 application end-to-end — operation-level security (`security`, `securityPostDenormalize` with `previous_object`, `securityPostValidation`, `throw_on_access_denied`), property-level security (`#[ApiProperty(security: ...)]`), Doctrine collection extensions for owner-scoped lists, voters, UUID/ULID identifiers (anti-enumeration), JWT authentication with LexikJWTAuthenticationBundle (keys, refresh tokens, HttpOnly cookies, RS256), OIDC alternative, CORS via nelmio/cors-bundle. Includes the 4.3 perf optimization where `isGranted` is evaluated before the state provider when `object` is not referenced. Trigger when wiring `security`, writing a voter, hiding an admin-only field, setting up JWT, fixing CORS, or auditing for security gaps.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Security

## Use when
- Wiring `security` / `securityPostDenormalize` / `securityPostValidation` on operations.
- Writing or testing a voter (`POST_VIEW`, `POST_EDIT`, etc.).
- Filtering a collection by owner via a Doctrine extension.
- Setting up JWT authentication (Lexik) or OIDC.
- Configuring CORS for public / partner consumers.
- Switching identifiers to UUID v7 or ULID to remove enumeration risk.

## Default workflow
1. Apply `security` per operation. Fail closed — no `security:` means public, only by design.
2. Decide between expression (simple) and **Voter** (complex). Cross more than one condition → Voter.
3. For mutations that mutate ownership, use `securityPostDenormalize` with `previous_object` to enforce invariants.
4. For each sensitive property, decide: group split, `#[ApiProperty(security: ...)]`, or both.
5. Identifiers: `Uuid::v7()` / `Ulid` on every public resource. No sequential IDs.

## Guardrails
- **Fail secure.** Anything not explicitly public is `is_granted('ROLE_USER')` minimum.
- **`securityMessage`** on every guarded operation — explicit feedback, no debug leakage.
- **`extraProperties: ['throw_on_access_denied' => true]`** — without it, an unauthorized field change is silently dropped instead of throwing 403.
- **Never log JWT contents.** JWT is readable; no PII in claims.
- **No `*` in CORS** when `allow_credentials: true`. List the explicit origins.
- **Tests cover refusal AND acceptance.** Both branches matter.

## Progressive disclosure
- `SKILL.md` lists the posture and decision tree.
- `reference.md` carries the full patterns: operation security expressions, voters, query extensions, property security, UUID/ULID, JWT (Lexik) end-to-end (keys, security.yaml, Swagger UI, refresh tokens, storage), OIDC alternative, CORS configuration, performance note 4.3.

## Output contract
- Each operation has an explicit `security` (or a documented public exception).
- Voters tested in isolation (`./vendor/bin/phpunit --filter=Voter`).
- Collection queries filtered through a `QueryCollectionExtensionInterface` + `QueryItemExtensionInterface`.
- Identifiers use UUID v7 / ULID where applicable.
- JWT / OIDC + CORS configurations match the published examples.

## References
- `reference.md`
