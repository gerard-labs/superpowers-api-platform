---
name: api-platform-filters
description: Build API Platform 4.3 filters with the modern `parameters` + `QueryParameter` pattern. Use when adding search, sort, range, full-text, or sparse-fieldset filtering to an operation. Covers `ExactFilter`, `PartialSearchFilter` (caseSensitive 4.3), `IriFilter` (nested), `UuidFilter` (4.3), `ComparisonFilter` (gt/gte/lt/lte/ne 4.3), `SortFilter` (nullsComparison), `FreeTextQueryFilter`, `OrFilter`, `ExistsFilter`, `BackedEnumFilter`, `PropertyFilter` (sparse, native 4.3), JSON:API `SparseFieldset`. Plus mandatory `property:` argument in 4.3, dot-notation nested, `castToNativeType` / `castToArray` / `castFn`, `strictQueryParameterValidation`, per-parameter security, Parameter Providers (IriConverter/ReadLink/custom), Doctrine SQL Filters for multi-tenant. **Never** `#[ApiFilter]` or `extends AbstractFilter` — legacy belongs to `api-platform-upgrade`.
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
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-filters/) + edge cases.
---

# API Platform 4.3 — Filters (modern parameters pattern)

## Use when
- Adding any query filter, sort, range, or full-text search to a `GetCollection`.
- Replacing existing `#[ApiFilter]` annotations (legacy) with the 4.3 modern pattern.
- Implementing a custom filter via `FilterInterface` + Json Schema + OpenAPI traits.
- Wiring a Parameter Provider (IRI converter, read link, custom dynamic group).
- Enforcing multi-tenant row-level security via a Doctrine SQL Filter.

## Default workflow
1. Identify the columns that must be filterable, sortable, or full-text searchable.
2. Declare `parameters: [...]` on the operation with one `new QueryParameter(filter: new XxxFilter(), property: '...')` per parameter.
3. Add `castToNativeType` / `castToArray` / `castFn` where the value needs a type or transformation.
4. Index every filtered column (`#[ORM\Index]`) and a functional index for case-insensitive partial searches.
5. Write tests that exercise each filter + boundary cases.

## Guardrails
- **`property` is mandatory in 4.3** on `ExactFilter`, `IriFilter`, `PartialSearchFilter`, `UuidFilter` — otherwise `InvalidArgumentException` at compile time. Use the literal property name or the `:property` placeholder.
- **Never use `#[ApiFilter]` or `extends AbstractFilter`** in new code — both are deprecated since 4.2 and removed in 5.0.
- **`IriFilter` for FKs**, never an `ExactFilter` on a scalar `userId` (IRI-only rule).
- **Indexing is non-optional** — without an index, a filter becomes a full scan.
- **`PartialSearchFilter` sparingly** — a case-insensitive partial search bypasses btree indexes; add a functional index on `LOWER(col)` when used.

## Progressive disclosure
- `SKILL.md` lists posture, the modern pattern, and rules.
- `reference.md` carries the full catalogue, dot-notation nested filters, `FreeTextQueryFilter` + `OrFilter`, `ComparisonFilter` operators (incl. `ne` 4.3), `SortFilter` `nullsComparison`, custom filter recipe (interfaces + traits), Parameter Providers (4.3), `PropertyFilter` native (4.3), default global parameters, Doctrine SQL Filter for multi-tenant, and the `make:filter orm/odm` generator.

## Output contract
- `parameters: [...]` arrays on operations — no `#[ApiFilter]` left.
- Tests asserting each filter against controlled data.
- Indices added on filtered columns (Doctrine `#[ORM\Index]`).
- Custom filters implement `FilterInterface`, `JsonSchemaFilterInterface`, `OpenApiParameterFilterInterface` (with the `OpenApiFilterTrait` + `BackwardCompatibleFilterDescriptionTrait`).

## References
- `reference.md`
