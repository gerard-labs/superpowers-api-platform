# API Platform 4.3 — Performance (reference)

## 1. Doctrine fetch modes

- **`LAZY` default** for most relations.
- **`EXTRA_LAZY`** for large collections — `count()`, `contains()`, `slice()` work without hydrating the whole collection.
- **Avoid `EAGER` at mapping level** — prefer per-query join fetches.

---

## 2. The 4.x eager-loading trap

⚠️ In 4.x the default is `eager_loading.force_eager: true`. API Platform eagerly loads **every** association in a join on each GET. Often counter-productive:

- On entities with many relations, `max_joins: 30` is hit quickly → exception.
- Hydrates fields that are never serialized (different groups).

**Disable and use targeted join fetches** (the recommended setup):

```yaml
api_platform:
    eager_loading:
        enabled:       true
        force_eager:   false       # IMPORTANT — keep explicit
        fetch_partial: false
        max_joins:     30
```

With `force_eager: false`, API Platform stays lazy by default; developers add `addSelect()` in query extensions or repositories.

### Enabling eager loading on a specific property

```php
use ApiPlatform\Metadata\ApiProperty;

#[ApiProperty(fetchEager: true)]
public Address $primaryAddress;
```

---

## 3. Targeted join fetch (repository pattern)

```php
public function findAllWithRelations(): array
{
    return $this->createQueryBuilder('p')
        ->addSelect('a', 't', 'c')              // otherwise Doctrine does not hydrate
        ->leftJoin('p.author', 'a')
        ->leftJoin('p.tags', 't')
        ->leftJoin('p.comments', 'c')
        ->orderBy('p.createdAt', 'DESC')
        ->getQuery()->getResult();
}
```

Without `addSelect()`, the JOIN happens but the joined entities stay un-hydrated → still an N+1.

---

## 4. Avoiding N+1

- **Profile systematically** with the Symfony profiler in dev.
- Spot `SELECT` queries inside a loop → add a join fetch.
- For list views: project a DTO directly with DQL `NEW`.

```php
->select('NEW App\Dto\PostListItem(p.id, p.title, a.name)')
->leftJoin('p.author', 'a')
```

---

## 5. Partial objects / DTOs in repository

- For list views, don't hydrate the entire entity.
- `PARTIAL p.{id, title, createdAt}` or `NEW DTO(...)`.

---

## 6. Batch iteration for huge volumes

```php
foreach ($qb->getQuery()->toIterable() as $entity) {
    $this->process($entity);
    $this->em->clear(Entity::class);   // free memory
}
```

Without `clear()`, memory grows linearly. Doctrine's identity map keeps everything.

Cf. `gerard:doctrine-batch-processing` for the deeper pattern.

---

## 7. `IndexBy` for fast lookups

```php
$posts = $repo->createQueryBuilder('p', 'p.id')->getQuery()->getResult();
$posts[42]; // direct access by ID
```

Useful when you need to cross-reference loaded entities by ID inside a hot loop.

---

## 8. `HINT_READ_ONLY`

```php
$qb->getQuery()->setHint(\Doctrine\ORM\Query::HINT_READ_ONLY, true)->getResult();
```

When the entities will not be modified — disables change tracking, saves memory and CPU.

---

## 9. APCu metadata cache

API Platform recomputes the resource metadata (groups, operations, types) on each boot. In production, **always wire a PSR-6 cache** — APCu is the sane default:

```yaml
framework:
    cache:
        pools:
            cache.api_platform:
                adapter: cache.adapter.apcu

api_platform:
    metadata_backward_compatibility_layer: false
```

Without a cache, each request recomputes the metadata tree (visibly slow once you have a handful of resources).

---

## 10. FrankenPHP worker mode

For high-traffic APIs, **FrankenPHP in worker mode** keeps the Symfony kernel in memory between requests — p99 latency drops considerably (often 80 ms → 8 ms on simple routes).

```dockerfile
ENV FRANKENPHP_CONFIG="worker /app/public/index.php"
```

Compatible with API Platform natively (the official distribution is FrankenPHP/Caddy-based).

Worker-mode requirements:

- No static state leaking between requests.
- Avoid mutable singletons.
- Listen to `kernel.request` / `kernel.response` for per-request cleanup if needed.

---

## 11. HTTP cache (operation-level)

```php
#[ApiResource(
    cacheHeaders: ['max_age' => 3600, 'shared_max_age' => 86400, 'vary' => ['Authorization']],
)]
class Product { /* ... */ }
```

ETag and Last-Modified are generated automatically by API Platform. The browser / Varnish / Nginx will respect `Cache-Control` and return 304 on conditional requests.

**Invalidation strategy** — don't forget to purge on writes.

---

## 12. Tag-based invalidation (Varnish / Nginx)

Problem: when a product changes, how do you purge every cached response that contains it? (product page, catalog list, recommended products)

API Platform supports `cacheTags`:

```php
#[ApiResource(
    cacheHeaders: ['max_age' => 3600],
    cacheTags:    ['products'],
)]
class Product { /* ... */ }
```

The `Cache-Tags: products` header is added automatically. Invalidate via a PURGE request:

```http
PURGE /api/products/123
Cache-Tags: products
```

Varnish / Nginx purges every response tagged accordingly.

### Native HTTP cache invalidation (Varnish only)

```yaml
api_platform:
    http_cache:
        invalidation:
            enabled: true
            varnish_urls: ['%env(VARNISH_URL)%']
```

API Platform issues `PURGE` requests automatically on writes when this is enabled.

---

## 13. Dynamic `Last-Modified` listener

When `Last-Modified` needs to be computed (e.g. `max(updatedAt)` of a collection), wire a `ViewEvent` listener:

```php
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ViewEvent;

final readonly class NotModifiedListener
{
    public function __invoke(ViewEvent $event): void
    {
        $request  = $event->getRequest();
        $response = new Response();

        $lastModified = $this->calculateLastModified(/* ... */);
        $response->setLastModified(new \DateTimeImmutable('@'.$lastModified));

        if ($response->isNotModified($request)) {
            $event->setResponse($response);
        }
    }
}
```

The **content-based ETag** is generated automatically by API Platform — no listener needed.

---

## 14. Resource and query-related rules

- **Cap collections.** Always cap `paginationMaximumItemsPerPage` (cf. `gerard:api-platform-pagination`).
- **Index every filter / sort column.** Without an index, every filter is a full scan.
- **Cursor pagination** for huge tables (cf. `gerard:api-platform-pagination`).
- **`SkipAutoconfigure`** (4.3) to bypass autoconfigure when measurable, for niche perf-critical services.

---

## 15. Measurement reflex

- Use `symfony/profiler` in dev.
- Use Blackfire / Tideways in staging.
- Track real production p50 / p95 / p99 latencies — improvements need numbers.

---

## 16. Related skills

- `gerard:doctrine-fetch-modes` — fetch modes, lazy / extra lazy / partial.
- `gerard:doctrine-batch-processing` — large-volume iteration.
- `gerard:symfony-cache` — cache pools, tags, HTTP cache.
- `gerard:api-platform-pagination` — partial pagination, cursor pagination.
- `gerard:api-platform-resilience` — async writes when sync is too slow.
- `gerard:api-platform-resources` — `cacheHeaders` and `cacheTags` on operations.
