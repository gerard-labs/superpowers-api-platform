---
name: api-platform-resources
description: Design or evolve API Platform 4.3 resources — choose operations (Get/GetCollection/Post/Put/Patch/Delete), apply the Resource-First principle (Resource ≠ Entity), enforce the IRI-only relation rule, model subresources with Link(fromClass:, toProperty:), set shortName / uriTemplate / itemUriTemplate, configure content negotiation (formats, patch_formats, LDP Allow/Accept-Post 4.3), and avoid the legacy Symfony controllers pattern. Trigger on requests like "create an API resource", "add an operation", "expose nested orders under a customer", or "model a subresource".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Resources & operations

## Use when
- Designing a new `#[ApiResource]` or evolving an existing one.
- Choosing which operations to expose and how to scope them.
- Modeling subresources (orders under a customer, items under an order).
- Forcing the IRI-only rule on relations.

## Default workflow
1. Define the operation boundary — which payload, which invariants, which actor.
2. Declare the operations explicitly (`new Get(...)`, `new Post(...)`, etc.) with per-operation groups, security, validation.
3. Apply the Resource-First principle — keep the Resource decoupled from the Entity unless they are genuinely identical.
4. Validate the contract end-to-end (`debug:router`, `api:openapi:export`, functional tests).

## Guardrails
- Resource ≠ Entity. The Resource is the **external contract**; do not let it leak Doctrine specifics.
- IRI-only on relations: never accept a scalar `int $customerId`, always a `Customer $customer` that API Platform resolves from `/api/customers/...`.
- No `use_symfony_listeners: true` unless you really need a Symfony controller — the providers/processors path is preferred.
- No magic operations: declare each one. `paginationItemsPerPage` default is **30** in 4.x (not 20).

## Progressive disclosure
- `SKILL.md` covers posture and decisions.
- `reference.md` carries the full 4.3 patterns: subresources with `Link`, `itemUriTemplate`, content negotiation, anti-patterns, legacy controllers (to avoid).

## Output contract
- Updated `#[ApiResource]` attributes with explicit operations and contexts.
- Justification for IRI-only (or, exceptionally, embedded) choices.
- Functional test coverage on each operation, including 404 / 401 / 403 / 422.
- Generated routes confirmed via `php bin/console debug:router | grep api`.

## References
- `reference.md`
