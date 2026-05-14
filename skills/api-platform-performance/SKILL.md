---
name: api-platform-performance
description: Tune API Platform 4.3 + Doctrine + Symfony performance — recognize the 4.x default trap `eager_loading.force_eager: true` (often counter-productive, switch to `false` + targeted join fetches), use `EXTRA_LAZY` for large collections, project DTOs in DQL (`NEW App\\Dto\\PostListItem(...)`) to avoid hydrating full entities for list views, iterate in batches with `toIterable()` + `EntityManager::clear()`, set `HINT_READ_ONLY` when entities are not mutated, cache resource metadata with APCu, run **FrankenPHP in worker mode** for stateful kernel + p99 latency drops, configure HTTP cache headers per operation (`cacheHeaders`), and invalidate Varnish / Nginx via `cacheTags` + PURGE. Also covers when to add a dynamic `Last-Modified` listener on `ViewEvent`. Trigger on "slow API", "N+1", "memory blow-up on collection", "too many joins (max_joins 30)", "p99 latency", "cache invalidation", or "force_eager problem".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Performance

## Use when
- The API is slower than expected, especially on list endpoints.
- A `max_joins: 30` exception fires because the entity has many relations.
- Memory blows up on large collections.
- p99 latency is above ~50 ms for simple routes.
- Cache invalidation cannot keep up with writes.

## Default workflow
1. Detect the `force_eager: true` trap. Switch to `false` and replace with targeted join fetches in repositories.
2. Profile with the Symfony profiler in dev — look for N+1 patterns.
3. For list views: project a DTO via DQL `NEW App\Dto\PostListItem(...)` instead of hydrating the full entity.
4. Enable APCu for resource metadata cache in prod.
5. Adopt FrankenPHP worker mode for high-traffic APIs (stateful kernel between requests).
6. Add HTTP cache headers per operation and `cacheTags` for invalidation.

## Guardrails
- **`force_eager: true`** is the 4.x default but rarely what you want for an entity with many relations. Set it to `false` and use targeted `addSelect()` join fetches per query.
- **`#[ApiProperty(fetchEager: true)]`** for specific fields only — never blanket eager loading.
- **Never iterate without `clear()`** on million-row collections — memory will explode.
- **HTTP cache + write paths** must agree on invalidation — purge `cacheTags` on every write.
- **FrankenPHP worker mode** requires worker-safe code (no static state leaks).

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full patterns: fetch modes, eager loading trap, join fetch recipe, DTO projection, batch iteration, HINT_READ_ONLY, APCu metadata cache, FrankenPHP worker, HTTP cache headers, cache tags + Varnish PURGE, dynamic Last-Modified listener.

## Output contract
- `eager_loading.force_eager: false` confirmed (or documented exception).
- Repository methods using targeted `addSelect()` for list endpoints.
- DTO projections via DQL `NEW` for large lists.
- APCu metadata cache configured in prod.
- HTTP cache configured per operation (where applicable).
- `cacheTags` purged on writes.
- p99 latency measured before/after.

## References
- `reference.md`
