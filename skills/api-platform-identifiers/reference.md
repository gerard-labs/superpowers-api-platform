# API Platform 4.3 — Identifiers (reference)

## 1. Natively supported types

- Scalar (`string`, `int`).
- `\DateTimeInterface` — serialized via `DateTimeUriVariableTransformer`.
- `\Ramsey\Uuid\Uuid`.
- `\Symfony\Component\Uid\Uuid` (recommended).
- `\Symfony\Component\Uid\Ulid` (recommended for cursor pagination).
- `\Stringable` (for composite identifiers).

---

## 2. UUID v7 — temporal cursor pagination

UUID v7 (timestamp + random) enables stable + scalable cursor pagination — see `gerard:api-platform-pagination`.

```php
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use Symfony\Component\Uid\Uuid;

#[ApiResource]
class Order
{
    #[ApiProperty(identifier: true)]
    public Uuid $id;     // Uuid::v7() set at creation time
}
```

Wire with cursor pagination + `UuidFilter`:

```php
use ApiPlatform\Doctrine\Orm\Filter\ComparisonFilter;
use ApiPlatform\Doctrine\Orm\Filter\UuidFilter;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\QueryParameter;

new GetCollection(
    paginationViaCursor: [['field' => 'id', 'direction' => 'DESC']],
    parameters: [
        'id' => new QueryParameter(
            filter:   new ComparisonFilter(new UuidFilter()),
            property: 'id',
        ),
    ],
)
// GET /api/orders?id[lt]=01H...&itemsPerPage=50
```

Database-side: a native `uuid` column (PostgreSQL) — better indexing and storage than `varchar(36)`.

---

## 3. Composite identifiers

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Link;

#[ApiResource(
    uriTemplate: '/customer/{customerId}/order/{orderId}',
    uriVariables: [
        'customerId' => new Link(fromClass: Customer::class, identifiers: ['id']),
        'orderId'    => new Link(fromClass: Order::class,    identifiers: ['id']),
    ],
)]
class OrderLine { /* ... */ }
```

API Platform routes `/customer/{customerId}/order/{orderId}` to the resource, resolving each piece via the associated `Link`.

---

## 4. Custom identifier (slug)

```php
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;

#[ApiResource]
class Article
{
    #[ApiProperty(identifier: true)]
    private string $slug;            // public API identifier

    #[ORM\Id, ORM\Column, ORM\GeneratedValue]
    #[ApiProperty(identifier: false)]
    private ?int $id = null;          // internal Doctrine ID
}
```

The IRI now uses `/articles/my-awesome-slug` while Doctrine keeps using the integer `id` for joins and indexing.

---

## 5. `UriVariableTransformerInterface` — string → object

Decorate when API Platform needs to coerce the URI fragment into a typed object that is not natively supported.

```php
use ApiPlatform\Metadata\UriVariableTransformerInterface;
use Symfony\Component\Uid\Uuid;

final class UuidUriVariableTransformer implements UriVariableTransformerInterface
{
    public function transform($value, array $types, array $context = []): Uuid
    {
        return Uuid::fromString($value);
    }

    public function supportsTransformation($value, array $types, array $context = []): bool
    {
        foreach ($types as $type) {
            if (is_a($type, Uuid::class, true)) {
                return true;
            }
        }
        return false;
    }
}
```

Auto-tagged when autoconfigure is on (`api_platform.uri_variables.transformer`).

---

## 6. `IdentifiersExtractorInterface` — custom output format

Decorate to format identifiers in the response (e.g. format a `\DateTime` as `Y-m-d` instead of ISO 8601).

```php
use ApiPlatform\Metadata\IdentifiersExtractorInterface;
use ApiPlatform\Metadata\Operation;
use Symfony\Component\DependencyInjection\Attribute\AutowireDecorated;

final class DateTimeIdentifiersExtractor implements IdentifiersExtractorInterface
{
    public function __construct(
        #[AutowireDecorated]
        private IdentifiersExtractorInterface $decorated,
    ) {}

    public function getIdentifiersFromItem(object $item, ?Operation $op = null, array $context = []): array
    {
        $ids = $this->decorated->getIdentifiersFromItem($item, $op, $context);
        foreach ($ids as $k => $v) {
            if ($v instanceof \DateTimeInterface) {
                $ids[$k] = $v->format('Y-m-d');
            }
        }
        return $ids;
    }
}
```

---

## 7. Choosing the right identifier — decision tree

| Use case | Recommendation |
|---|---|
| Public resource, no chronological need | **UUID v4** (random). |
| Public resource, cursor pagination wanted | **UUID v7** (chronological prefix + random). |
| Public resource, human-readable URL needed | **Slug** (custom identifier). |
| Internal resource (admin-only, no enumeration risk) | Auto-increment `int` acceptable, but UUID is still preferable for portability. |
| Parent-child route (nested resource) | **Composite identifier** via `Link(uriVariables: …, identifiers: …)`. |
| Existing legacy resource with int `id` | Keep the int as the Doctrine ID; expose a slug or UUID as the public identifier. |

---

## 8. Database column tips

- **PostgreSQL**: use `uuid` native type.
- **MySQL** (no native UUID): store as `BINARY(16)` for compactness or `CHAR(36)` for readability.
- **Always index** the identifier column.
- For **UUID v7**, a clustered index works well (the chronological prefix means inserts are append-friendly).

---

## 9. Related skills

- `gerard:api-platform-pagination` — cursor pagination relies on chronologically sortable identifiers.
- `gerard:api-platform-resources` — `#[ApiProperty(identifier: true)]`, IRI-only rule.
- `gerard:api-platform-security` — UUID/ULID as an anti-enumeration measure.
- `gerard:api-platform-filters` — `UuidFilter` (4.3).
- `gerard:doctrine-relations` — composite primary keys.
