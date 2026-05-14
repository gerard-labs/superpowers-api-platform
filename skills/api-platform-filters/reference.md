# API Platform 4.3 — Filters (reference)

> ⚠️ Major break 4.2 → 4.3: `#[ApiFilter]` and `AbstractFilter` are deprecated and will be removed in 5.0. The new pattern instantiates filters directly inside `parameters` of an operation, via `QueryParameter` / `HeaderParameter`. In 4.3, **`property` is explicit-required** on `ExactFilter`, `IriFilter`, `PartialSearchFilter`, `UuidFilter` (otherwise `InvalidArgumentException` at compile time).

## 1. The modern pattern (4.2+, fully embraced in 4.3)

```php
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\QueryParameter;
use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Doctrine\Orm\Filter\ComparisonFilter;
use ApiPlatform\Doctrine\Orm\Filter\PartialSearchFilter;
use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Doctrine\Orm\Filter\SortFilter;
use ApiPlatform\Doctrine\Orm\Filter\FreeTextQueryFilter;
use ApiPlatform\Doctrine\Orm\Filter\OrFilter;

#[GetCollection(
    parameters: [
        // Exact match (replaces SearchFilter::exact)
        'sku'      => new QueryParameter(filter: new ExactFilter(), property: 'sku'),

        // Case-insensitive partial search (replaces SearchFilter::partial)
        'name'     => new QueryParameter(filter: new PartialSearchFilter(), property: 'name'),

        // Filter by IRI to another resource (replaces SearchFilter on FK)
        'category' => new QueryParameter(filter: new IriFilter(), property: 'category'),

        // Range / comparison (replaces DateFilter, RangeFilter, NumericFilter ranges)
        'price'     => new QueryParameter(filter: new ComparisonFilter(new ExactFilter()), property: 'price'),
        'createdAt' => new QueryParameter(filter: new ComparisonFilter(new ExactFilter()), property: 'createdAt'),

        // Sort (replaces OrderFilter)
        'orderName' => new QueryParameter(filter: new SortFilter(), property: 'name'),
        'orderDate' => new QueryParameter(filter: new SortFilter(), property: 'createdAt'),

        // Boolean (replaces BooleanFilter — an ExactFilter accepts true/false/1/0)
        'isActive'  => new QueryParameter(filter: new ExactFilter(), property: 'isActive'),
    ],
)]
class Product { /* ... */ }
```

---

## 2. Filter catalogue (4.3)

| Modern filter | Replaces (legacy) | Usage |
|---|---|---|
| `ExactFilter` | `SearchFilter::exact`, `BooleanFilter`, exact `NumericFilter` | `?prop=value` (index-friendly). **`property` required in 4.3.** |
| `PartialSearchFilter` | `SearchFilter::partial` / `start` / `end` / `word_start` | `?prop=value` (LIKE %v%). `caseSensitive: bool` option in 4.3. **`property` required.** |
| `IriFilter` | `SearchFilter` on a relation | `?category=/api/categories/1`. Supports nested `department.company` in 4.3. **`property` required.** |
| `UuidFilter` (4.3) | — | Native UUID, useful for cursor pagination on UUID v7. **`property` required.** |
| `ComparisonFilter` | `DateFilter`, `RangeFilter`, `NumericFilter` ranges | `?price[gt|gte|lt|lte|ne]=value`. **`ne` operator added in 4.3.** |
| `SortFilter` | `OrderFilter` | `?orderName=asc&orderDate=desc`. `nullsComparison: NULLS_ALWAYS_LAST` + nested `department.name`. ODM supported in 4.3. |
| `FreeTextQueryFilter` | Multi-field search | `?q=tom` across N properties (AND by default). |
| `OrFilter` | (decorator) | Combines with OR instead of AND. Wraps another filter. |
| `ExistsFilter` | (unchanged) | `?exists[deletedAt]=false`. |
| `BackedEnumFilter` | (new) | For native `BackedEnum` columns. |
| `PropertyFilter` | — | Sparse fieldsets : `?properties[]=title&properties[]=author`. Whitelist via config. **Native in 4.3.** |
| `SparseFieldset` | — | JSON:API specific : `?fields[Book]=title,author`. |

### `ComparisonFilter` operators

- `gt`  → `>`
- `gte` → `>=`
- `lt`  → `<`
- `lte` → `<=`
- `ne`  → `!=` (4.3)

Native support for ISO 8601 dates (auto-cast to `DateTimeImmutable`) and UUIDs (lexicographic — useful for cursor pagination on UUID v7).

```http
GET /api/products?createdAt[gte]=2025-01-01&createdAt[lte]=2025-01-31
GET /api/products?price[gte]=1000&price[lte]=5000
GET /api/products?price[ne]=0
```

---

## 3. Custom filters (4.2+)

Implement `FilterInterface` (no `AbstractFilter`) with the compatibility trait:

```bash
bin/console make:filter orm MonthFilter        # Doctrine ORM
bin/console make:filter odm MonthFilter        # Doctrine ODM
```

```php
use ApiPlatform\Doctrine\Common\Filter\OpenApiFilterTrait;
use ApiPlatform\Doctrine\Orm\Filter\FilterInterface;
use ApiPlatform\Doctrine\Orm\Util\QueryNameGeneratorInterface;
use ApiPlatform\Metadata\BackwardCompatibleFilterDescriptionTrait;
use ApiPlatform\Metadata\JsonSchemaFilterInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\OpenApiParameterFilterInterface;
use ApiPlatform\Metadata\Parameter;
use Doctrine\ORM\QueryBuilder;

final class MonthFilter implements
    FilterInterface,
    JsonSchemaFilterInterface,
    OpenApiParameterFilterInterface
{
    use BackwardCompatibleFilterDescriptionTrait;
    use OpenApiFilterTrait;

    public function apply(
        QueryBuilder $qb,
        QueryNameGeneratorInterface $gen,
        string $resourceClass,
        ?Operation $operation = null,
        array $context = [],
    ): void {
        $parameter = $context['parameter'];
        $value     = $parameter->getValue();
        $property  = $parameter->getProperty();

        $alias = $qb->getRootAliases()[0];
        $p     = $gen->generateParameterName($property);

        $qb->andWhere(sprintf('MONTH(%s.%s) = :%s', $alias, $property, $p))
           ->setParameter($p, $value);
    }

    public function getSchema(Parameter $parameter): array
    {
        return ['type' => 'integer', 'minimum' => 1, 'maximum' => 12];
    }
}
```

- **No `services.yaml` entry needed** — filters are no longer registered as services in the modern pattern.
- **`JsonSchemaFilterInterface`** validates the value before `apply()` (range, enum, type).
- **`OpenApiFilterTrait`** auto-generates the OpenAPI doc.

---

## 4. Filtering across relations (dot notation)

Modern filters support traversal via dotted property paths. A single JOIN is generated even if multiple parameters traverse the same relation.

```php
parameters: [
    'department'    => new QueryParameter(filter: new IriFilter(),  property: 'department'),
    'orderDeptName' => new QueryParameter(filter: new SortFilter(), property: 'department.name'),
    'orderCompany'  => new QueryParameter(filter: new SortFilter(), property: 'department.company.name'),
]
```

---

## 5. Multi-property search with `FreeTextQueryFilter`

```php
'q' => new QueryParameter(
    filter: new FreeTextQueryFilter(new PartialSearchFilter()),
    properties: ['name', 'ean'],
),
```

`?q=tom` applies the filter on each property, combined with AND by default. For autocomplete-style OR, wrap in `OrFilter`:

```php
'autocomplete' => new QueryParameter(
    filter: new FreeTextQueryFilter(new OrFilter(new ExactFilter())),
    properties: ['name', 'ean'],
),
```

---

## 6. Native enum filter — `BackedEnumFilter`

```php
'status' => new QueryParameter(filter: new BackedEnumFilter(), property: 'status'),
```

Pair with the `BackedEnum` pattern from `gerard:api-platform-serialization`.

---

## 7. `PartialSearchFilter` — case-sensitive option (4.3)

By default `PartialSearchFilter` is **case-insensitive** (uses `LOWER()`). In 4.3, opt in to case-sensitive matching:

```php
'name' => new QueryParameter(filter: new PartialSearchFilter(caseSensitive: true), property: 'name'),
```

**Performance**: a case-insensitive partial filter on a column without a functional index is a full-table scan. Add a functional index:

```sql
CREATE INDEX idx_product_name_lower ON product (LOWER(name));
```

---

## 8. Cast options (4.3)

`QueryParameter` accepts several cast options to coerce the raw string value before it reaches the filter:

```php
parameters: [
    // Native-type cast from the JSON Schema
    'active' => new QueryParameter(
        schema:           ['type' => 'boolean'],
        castToNativeType: true,                     // "true" → bool true
    ),

    // Array cast (?tags[]=php&tags[]=api → ['php', 'api'])
    'tags' => new QueryParameter(castToArray: true),

    // Custom cast
    'code' => new QueryParameter(castFn: fn ($v) => strtoupper($v)),
]
```

---

## 9. Parameter validation

```php
use Symfony\Component\Validator\Constraints as Assert;

parameters: [
    'country' => new QueryParameter(
        constraints: [new Assert\Country()],
        required:    true,
    ),
    'age' => new QueryParameter(
        schema:           [
            'type'    => 'integer',
            'minimum' => 18,
            'maximum' => 120,
        ],
        castToNativeType: true,
    ),
]
```

JSON Schema constraints are **automatically converted** into Symfony constraints:

| Schema | Symfony Constraint |
|---|---|
| `minimum` / `maximum` | `Range` |
| `pattern` | `Regex` |
| `minLength` / `maxLength` | `Length` |
| `enum` | `Choice` |
| `multipleOf` | `DivisibleBy` |

### Strict validation of unknown parameters (4.3)

```php
new GetCollection(
    strictQueryParameterValidation: true,       // unknown parameters → HTTP 400
    parameters: [
        'name' => new QueryParameter(),
    ],
)
```

`?name=foo&unknownParam=bar` returns 400 instead of silently ignoring the extra parameter.

---

## 10. Per-parameter security

```php
'adminOnly' => new QueryParameter(
    security: 'is_granted("ROLE_ADMIN")',
),

'secretFilter' => new QueryParameter(
    security: '"secretkey" == secret',     // value read from another parameter
),
```

Useful to expose a parameter only to certain roles.

---

## 11. `SortFilter` — null strategies (4.3)

```php
use ApiPlatform\Doctrine\Common\Filter\OrderFilterInterface;

'orderName' => new QueryParameter(
    filter:   new SortFilter(nullsComparison: OrderFilterInterface::NULLS_ALWAYS_LAST),
    property: 'name',
),
```

Constants: `NULLS_ALWAYS_FIRST`, `NULLS_ALWAYS_LAST`, `NULLS_SMALLEST`, `NULLS_LARGEST`.

---

## 12. Parameter Providers (4.3)

Transform the parameter value before it hits the filter.

```php
use ApiPlatform\State\Provider\IriConverterParameterProvider;
use ApiPlatform\State\Provider\ReadLinkParameterProvider;

parameters: [
    // Converts ?user=/users/42 into the User entity
    'user' => new QueryParameter(
        provider:        IriConverterParameterProvider::class,
        extraProperties: ['fetch_data' => true],
    ),

    // Reads the parent link from the URI template
    'author' => new QueryParameter(
        provider:        ReadLinkParameterProvider::class,
        extraProperties: [
            'resource_class' => User::class,
            'uri_template'   => '/users/{id}',
        ],
    ),
]
```

### Custom Parameter Provider

```php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Parameter;
use ApiPlatform\State\ParameterProviderInterface;

final class DynamicGroupProvider implements ParameterProviderInterface
{
    public function provide(Parameter $parameter, array $parameters = [], array $context = []): ?Operation
    {
        $operation = $context['operation'];
        if ('extended' === $parameter->getValue()) {
            $ctx = $operation->getNormalizationContext();
            $ctx['groups'][] = 'extended_read';
            return $operation->withNormalizationContext($ctx);
        }
        return $operation;
    }
}

// Usage: ?view=extended → adds the `extended_read` group
parameters: ['view' => new QueryParameter(provider: DynamicGroupProvider::class)]
```

---

## 13. `PropertyFilter` — native sparse fieldsets (4.3)

```php
use ApiPlatform\Serializer\Filter\PropertyFilter;

#[ApiResource(
    parameters: ['properties' => new QueryParameter(filter: PropertyFilter::class)],
)]
class Book { /* ... */ }
```

```http
GET /books?properties[]=title&properties[]=author
GET /books?properties[]=title&properties[author][]=name
```

### Global configuration

```yaml
api_platform:
    defaults:
        parameters:
            properties:
                key:                          'properties'
                parameter_name:               'properties'
                override_default_properties:  false
                whitelist:                    ['title', 'author', 'isbn']
```

---

## 14. Global default parameters (4.3)

Applied to every operation without explicit declaration:

```yaml
api_platform:
    defaults:
        parameters:
            ApiPlatform\Metadata\HeaderParameter:
                key:         'X-Api-Token'
                required:    true
                description: 'API authentication token'
```

---

## 15. Hide a parameter from the documentation

```php
'internal' => new QueryParameter(openApi: false, hydra: false)
```

## 16. Custom OpenAPI parameter

```php
use ApiPlatform\OpenApi\Model\Parameter as OpenApiParameter;

'status' => new QueryParameter(
    schema:  ['enum' => ['draft', 'published']],
    openApi: new OpenApiParameter(name: 'status', in: 'query', style: 'deepObject'),
)
```

---

## 17. Doctrine SQL Filters for row-level security

For multi-tenant or B2B2C isolation, use a native Doctrine `SQLFilter` (distinct from API Platform filters):

```php
use Doctrine\ORM\Mapping\ClassMetadata;
use Doctrine\ORM\Query\Filter\SQLFilter;

final class TenantFilter extends SQLFilter
{
    public function addFilterConstraint(ClassMetadata $meta, $alias): string
    {
        $tenantAware = $meta->getReflectionClass()->getAttributes(TenantAware::class)[0] ?? null;
        if (!$tenantAware) return '';

        $tenantId = $this->getParameter('tenant_id');
        $field    = $tenantAware->getArguments()['field'];
        return sprintf('%s.%s = %s', $alias, $field, $tenantId);
    }
}
```

```yaml
doctrine:
    orm:
        filters:
            tenant_filter: { class: App\Filter\TenantFilter, enabled: true }
```

Applied across every Doctrine query — invisible to Providers / Processors.

---

## 18. Index — the golden rule

**Always index the columns you filter on.** Without an index, a filter is a full scan.

```php
#[ORM\Index(columns: ['name'],                          name: 'idx_product_name')]
#[ORM\Index(columns: ['price'],                         name: 'idx_product_price')]
#[ORM\Index(columns: ['created_at'],                    name: 'idx_product_created')]
#[ORM\Index(columns: ['is_active', 'deleted_at'],       name: 'idx_product_active')]
class Product { /* ... */ }
```

For case-insensitive partial searches, add a functional index on `LOWER(col)`.

---

## 19. Best practices summary

1. **`parameters` + `QueryParameter` pattern** — never `#[ApiFilter]` in new code.
2. **`IriFilter` for FKs**, never a scalar identifier in a filter (consistent with the IRI-only rule).
3. **Index every filtered column.**
4. **Limit the exposed properties** — don't filter on everything by default.
5. **`PartialSearchFilter` sparingly** (index loss). Add a functional index when used.
6. **`JsonSchemaFilterInterface`** on custom filters (validation + OpenAPI).
7. **Doctrine SQLFilter** for multi-tenant row-level security.

---

## 20. Related skills

- `gerard:api-platform-resources` — operation declaration, parameter wiring.
- `gerard:api-platform-pagination` — cursor pagination + `UuidFilter` + `ComparisonFilter`.
- `gerard:api-platform-tests` — testing each filter against controlled data.
- `gerard:api-platform-security` — parameter-level security, multi-tenant isolation.
- `gerard:api-platform-upgrade` — migration from `#[ApiFilter]` + `AbstractFilter` to the modern pattern.
- `gerard:doctrine-fetch-modes` — indexing and query performance considerations.
