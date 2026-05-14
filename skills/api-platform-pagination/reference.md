# API Platform 4.3 — Pagination (reference)

## 1. Defaults (4.x)

- Pagination enabled.
- **30 items per page** (`defaults.pagination_items_per_page: 30`) — changed from 20 in 3.x.
- Query string: `?page=2&itemsPerPage=50`.
- Parameter names configurable via `collection.pagination.{page,items_per_page,enabled,partial}_parameter_name`.
- **`hydra_prefix: false`** is the 4.x default — the response uses `member`, `totalItems`, `view`, `next`, `previous` **without** the `hydra:` prefix:

```json
{
  "@context":   "/api/contexts/Product",
  "@id":        "/api/products",
  "@type":      "Collection",
  "totalItems": 100,
  "member":     [ /* ... */ ],
  "view": {
    "@id":  "/api/products?page=1",
    "next": "/api/products?page=2"
  }
}
```

### Restore the legacy `hydra:` prefix (compat with old clients)

```yaml
api_platform:
    serializer:
        hydra_prefix: true
```

---

## 2. Partial pagination — skip the COUNT

For large collections, drop the COUNT query (`totalItems` is no longer surfaced):

```php
#[ApiResource(paginationPartial: true)]
class Order { /* ... */ }
```

The response is more compact (`first`, `next`, `previous` — no `last` or `totalItems`). A net win on tables with millions of rows.

---

## 3. Cursor pagination — UUID v7 / ULID

Stable and performant (no offset) on a single sortable unique field. Requires an identifier that is chronologically sortable.

```php
use ApiPlatform\Doctrine\Orm\Filter\ComparisonFilter;
use ApiPlatform\Doctrine\Orm\Filter\UuidFilter;
use ApiPlatform\Doctrine\Orm\Filter\SortFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\QueryParameter;
use Symfony\Component\Uid\Uuid;

#[ApiResource(
    paginationPartial:   true,
    paginationViaCursor: [['field' => 'id', 'direction' => 'DESC']],
)]
#[GetCollection(
    parameters: [
        'id' => new QueryParameter(
            filter:   new ComparisonFilter(new UuidFilter()),
            property: 'id',
        ),
        'orderId' => new QueryParameter(filter: new SortFilter(), property: 'id'),
    ],
)]
class Order
{
    #[ApiProperty(identifier: true)]
    public Uuid $id;     // Uuid::v7() at creation time — timestamp prefix + random
}
```

### Client navigation

```http
GET /api/orders?orderId=desc&itemsPerPage=50
GET /api/orders?id[lt]=01H...&orderId=desc&itemsPerPage=50    # next page
```

---

## 4. Doctrine paginator options

```php
#[ApiResource(
    paginationFetchJoinCollection: false,   // fetch-join on collection (perf)
    paginationUseOutputWalkers:    false,   // output walkers (grouping compat)
)]
```

- **`paginationFetchJoinCollection`** controls whether the paginator uses a single query with JOIN FETCH or multiple queries. Set to `false` for HUGE collections; `true` (default) avoids N+1 when the page contains entities with collections.
- **`paginationUseOutputWalkers`** controls Doctrine's output walker mode. Set to `false` for simple queries (faster); `true` when `GROUP BY` / `DISTINCT` is involved.

---

## 5. Custom parameter names

```yaml
api_platform:
    collection:
        pagination:
            page_parameter_name:           '_page'
            items_per_page_parameter_name: '_size'
            enabled_parameter_name:        '_paginate'
            partial_parameter_name:        '_partial'
```

Useful when integrating with a frontend convention you cannot change.

---

## 6. Capping the page size — anti-DoS

```php
#[ApiResource(
    paginationItemsPerPage:        30,
    paginationMaximumItemsPerPage: 100,
)]
class Product { /* ... */ }
```

A client request of `?itemsPerPage=10000` gets capped to 100 — no extra config needed.

---

## 7. Custom paginators

For non-Doctrine sources (search engines, external APIs, computed projections), implement `PartialPaginatorInterface` (no COUNT) or `PaginatorInterface` (with COUNT).

```php
use ApiPlatform\State\Pagination\TraversablePaginator;

return new TraversablePaginator(
    new \ArrayIterator($mappedItems),
    $currentPage,
    $itemsPerPage,
    $totalItems,
);
```

`TraversablePaginator` wraps an iterable and exposes the API Platform pagination metadata.

---

## 8. Test patterns (4.x JSON-LD)

```php
public function test_collection_is_paginated_with_default_30_items(): void
{
    ProductFactory::createMany(50);

    $response = static::createClient()->request('GET', '/api/products');
    $data     = $response->toArray();

    $this->assertCount(30, $data['member']);      // 30, not 20
    $this->assertEquals(50, $data['totalItems']); // no hydra: prefix
    $this->assertArrayHasKey('view', $data);
    $this->assertArrayHasKey('next', $data['view']);
}

public function test_custom_items_per_page(): void
{
    ProductFactory::createMany(20);

    $response = static::createClient()->request('GET', '/api/products?itemsPerPage=5');
    $this->assertCount(5, $response->toArray()['member']);
}
```

---

## 9. Best practices

- **Cap `itemsPerPage`** (100 max usually) — prevent silent DoS.
- **Test pagination** systematically (page size, navigation, total).
- **Cursor pagination** on huge datasets when the sort key is stable (UUID v7 / ULID = ideal).
- **`paginationPartial: true`** as soon as the table grows beyond ~100k rows (COUNT becomes slow).
- **Adapt legacy tests**: `$data['member']` instead of `$data['hydra:member']`.
- **Custom paginator** for non-relational sources — wrap in `TraversablePaginator`.

---

## 10. Related skills

- `gerard:api-platform-identifiers` — UUID v7 / ULID as cursor keys.
- `gerard:api-platform-filters` — `UuidFilter` + `ComparisonFilter` (4.3) for cursor pagination.
- `gerard:api-platform-performance` — eager loading, force_eager trap.
- `gerard:api-platform-tests` — JSON-LD shape (`member`, `totalItems`, no `hydra:` prefix).
- `gerard:doctrine-fetch-modes` — paginator performance considerations.
