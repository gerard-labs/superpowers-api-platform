# API Platform 4.3 — Input/Output DTOs (reference)

## 1. Why DTOs

- **Decouple the API contract from the Doctrine entity.** The entity is free to evolve internally without breaking the contract.
- **Validate at the boundary** (Input side).
- **Optimize reads** — the Output DTO is a lightweight projection.
- **Separate read and write contracts** explicitly. A `Create*Input` and an `Update*Input` can carry different invariants.

When the mapping between contract and entity is **mechanical** (field rename, format), prefer the **Symfony Object Mapper 4.3** integration documented at the end of this reference.

---

## 2. Input DTO — rules

- `final readonly` (PHP 8.1+).
- Symfony validator attributes directly on the properties.
- `#[Assert\Valid]` on nested collections.
- **No business logic** — strictly validated transport.
- **Always Resources (resolved via IRI), never scalar IDs** (cf. `api-platform-resources` §4 — the IRI-only rule).
- **Always a `BackedEnum`** for a status, a type, a category — never free `string`.

```php
use App\Entity\Customer;
use App\Entity\Coupon;
use Symfony\Component\Validator\Constraints as Assert;

final readonly class CreateOrderInput
{
    public function __construct(
        // IRI → Customer entity, NOT int $customerId
        #[Assert\NotNull]
        public Customer $customer,

        #[Assert\Count(min: 1, minMessage: 'Order must have at least one item')]
        #[Assert\Valid]
        public array $items,

        public ?Coupon $coupon = null,
    ) {}
}
```

Corresponding request:

```json
POST /api/orders
{
  "customer": "/api/customers/01J9...",
  "items": [
    { "product": "/api/products/01J8...", "quantity": 2 }
  ],
  "coupon": "/api/coupons/SUMMER25"
}
```

API Platform resolves each IRI to its entity **before** invoking the Processor — security, voters, access checks apply uniformly to every relation.

---

## 3. Output DTO — rules

- `final readonly`.
- Explicit factory (`static function fromEntity(Order $order): self`) — avoid magic.
- Serialize Value Objects through nested DTOs (`MoneyOutput::fromValueObject($money)`).
- Format dates in ISO 8601 (`->format('c')`).
- **Status = `BackedEnum`** (typed, documented as `enum` in OpenAPI, filterable via `BackedEnumFilter`).

```php
enum OrderStatus: string
{
    case Draft                = 'draft';
    case PendingErpProcessing = 'pending_erp_processing';
    case Processed            = 'processed';
    case Failed               = 'failed';
}

final readonly class OrderOutput
{
    public function __construct(
        public \Symfony\Component\Uid\Uuid $id,
        public Customer $customer,        // serialized as IRI
        public array $items,
        public MoneyOutput $total,
        public OrderStatus $status,        // BackedEnum, not string
        public \DateTimeImmutable $createdAt,
    ) {}

    public static function fromEntity(Order $order): self { /* ... */ }
}
```

Corresponding response:

```json
{
  "@id": "/api/orders/01J9...",
  "@type": "Order",
  "customer": "/api/customers/01J9...",
  "status": "pending_erp_processing",
  "total": { "amount": 15420, "currency": "EUR" },
  "createdAt": "2026-05-11T09:15:00+00:00"
}
```

API Platform natively serializes and deserializes `BackedEnum`: OpenAPI exposes `enum: [draft, pending_erp_processing, …]`; Doctrine can persist the column as `enumType: OrderStatus::class`.

---

## 4. Wiring on the operation

```php
#[ApiResource(
    operations: [
        new Post(
            input:     CreateOrderInput::class,
            output:    OrderOutput::class,
            processor: CreateOrderProcessor::class,
        ),
    ],
)]
class Order { /* ... */ }
```

The `provider:` is typically wired on read operations (`Get`, `GetCollection`) — see `gerard:api-platform-state-providers`.

---

## 5. Minor best practices

- **Separate Input and Output.** Different validation, groups, visibility.
- **One Input per operation** when invariants differ (`CreateOrderInput` ≠ `UpdateOrderInput`).
- **Do not expose internal IDs** on the Input side if the identifier comes from the URI.
- **Document DTO changes between versions** in a short header comment in the DTO file. Example:

```php
/**
 * Product representation (API v2).
 *
 * Changes from v1:
 * - `price` is now an object with `amount` and `currency`
 * - Added `sku`
 * - Removed `priceInCents` (use `price.amount`)
 */
final readonly class ProductOutputV2 { /* ... */ }
```

---

## 6. Object Mapper 4.3 — automatic DTO ↔ Entity mapping

> 🆕 API Platform 4.3 integrates Symfony Object Mapper. It auto-maps DTO ↔ Entity for **simple** cases (field rename, format), skipping the need for a custom Provider/Processor. Source: <https://api-platform.com/docs/core/dto/>.

### Prerequisite

```bash
composer require symfony/object-mapper:^7.4
```

### Pattern

Annotate the **DTO Resource** with `#[Map]` pointing to the Entity, and annotate each property with its source mapping.

```php
use ApiPlatform\Doctrine\Orm\State\Options;
use ApiPlatform\Metadata\ApiResource;
use Symfony\Component\ObjectMapper\Attribute\Map;
use App\Entity\BookEntity;

#[ApiResource(
    stateOptions: new Options(entityClass: BookEntity::class),
)]
#[Map(source: BookEntity::class)]
final class Book
{
    #[Map(source: 'id')]
    public ?int $id = null;

    #[Map(source: 'title')]
    public string $name;

    #[Map(transform: [self::class, 'formatPrice'])]
    public string $displayPrice;

    public static function formatPrice(BookEntity $entity): string
    {
        return number_format($entity->getPrice() / 100, 2) . ' €';
    }
}
```

### Flow

- **Read**: Doctrine → Entity → ObjectMapper → DTO (`Book`) → JSON.
- **Write**: JSON → DTO (`Book`) → ObjectMapper → Entity → Doctrine persist → ObjectMapper → DTO Resource → JSON.

### Auto-activation conditions

The Object Mapper integration kicks in automatically when:

1. `symfony/object-mapper` is installed.
2. `stateOptions: new Options(entityClass: …)` is configured on the resource.
3. The DTO and the Entity are both annotated with `#[Map]`.

Two internal decorators handle the rest: `ObjectMapperProvider` and `ObjectMapperProcessor` — **no service declaration required**.

### When to use it

- Renaming a field (`title` → `name` on the API side).
- Computing a display field (`displayPrice` from `price` in cents).
- Hiding internal fields by simply omitting `#[Map]` on them.
- Cutting Provider/Processor boilerplate on basic CRUDs.

### When **not** to use it

- Complex persistence logic → keep an explicit Processor.
- Aggregating multiple entities → keep an explicit Provider.
- The mapping diverges significantly → DTO + Provider/Processor (consistent with the Resource ≠ Entity principle).
- Side effects (event dispatch, async writes) → explicit Processor.

---

## 7. Related skills

- `gerard:api-platform-resources` — IRI-only rule, operations, Resource ≠ Entity.
- `gerard:api-platform-state-providers` — when you need a Provider (Object Mapper does not cover aggregation).
- `gerard:api-platform-state-processors` — when you need a Processor (Object Mapper does not cover side effects).
- `gerard:api-platform-serialization` — `BackedEnum`, `#[Context]`, groups.
- `gerard:value-objects-and-dtos` — generic VO / DTO design.
