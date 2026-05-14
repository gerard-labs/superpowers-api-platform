---
name: api-platform-pagination
description: Configure API Platform 4.3 pagination — default page size (30 items in 4.x, not 20), `hydra_prefix: false` shape (`member` / `totalItems` / `view` / `next` keys, no `hydra:` prefix), partial pagination (`paginationPartial: true`) to skip the COUNT on large tables, cursor-based pagination via `paginationViaCursor` paired with UUID v7 / ULID identifiers, `paginationMaximumItemsPerPage` to prevent DoS, fetch-join collection / output walker tuning, custom paginator implementations (`PartialPaginatorInterface`, `PaginatorInterface`, `TraversablePaginator`), and renaming the client parameters via `collection.pagination.{page,items_per_page,enabled,partial}_parameter_name`. Trigger when listing a resource that may grow beyond ~100k rows, when designing infinite-scroll / autocomplete APIs, or when fixing slow `COUNT(*)` queries.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Pagination

## Use when
- The collection can grow to millions of rows and `COUNT(*)` is too expensive.
- Infinite-scroll / autocomplete needs cursor pagination on a chronologically sortable key.
- Default 30 items per page is wrong for your domain (raise or lower it explicitly).
- Custom paginator needed (search engine, external API, computed projections).

## Default workflow
1. Verify the 4.x defaults: `pagination_items_per_page: 30`, `hydra_prefix: false`. Adapt tests.
2. Cap `paginationMaximumItemsPerPage` (50-100) per operation — anti-DoS.
3. For large tables: `paginationPartial: true` (no COUNT, no `totalItems`).
4. For infinite scroll: identifier = UUID v7 / ULID + `paginationViaCursor` + `ComparisonFilter` on the cursor field.
5. For non-Doctrine sources: implement a custom `PaginatorInterface`.

## Guardrails
- **`hydra_prefix: false`** is the default — tests must use `member` / `totalItems` / `view` / `next` (no `hydra:` prefix).
- **Default page size is 30** in 4.x (changed from 20 in 3.x) — fix tests that hard-code 20.
- **Always cap the max page size** to prevent abusers from requesting `?itemsPerPage=10000`.
- **Cursor pagination requires a stable sort key** — UUID v7 / ULID are ideal; auto-increment IDs work but leak volume.

## Progressive disclosure
- `SKILL.md` lists posture and rules.
- `reference.md` carries the full patterns: 4.x JSON-LD shape, partial pagination, cursor with UUID v7, fetch-join collection / output walkers, custom parameter names, custom paginator, best practices.

## Output contract
- Operations declare `paginationItemsPerPage`, `paginationMaximumItemsPerPage`, and where applicable `paginationPartial` / `paginationViaCursor`.
- Tests assert the 4.x JSON-LD shape (no `hydra:` prefix).
- Cursor pagination uses an indexed sort key; performance verified on a representative dataset.

## References
- `reference.md`
