# Doctrine Relations (reference)

> Companion to `SKILL.md`. Symfony 7.4+ / Doctrine ORM.

## 1. Relation types — quick reference

| Type | When | Owner side |
|---|---|---|
| `ManyToOne` | Many `Order` belong to one `Customer` | Order (carries the FK) |
| `OneToMany` | One `Customer` has many `Order` | Order (the ManyToOne side owns) |
| `ManyToMany` | Many `Article` ↔ many `Tag` | Either side — pick the one that mutates more |
| `OneToOne` | One `User` has one `UserPreference` | Pick the side that depends on the other |

## 2. ManyToOne + OneToMany (most common)

```php
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Index(columns: ['customer_id'], name: 'idx_order_customer')]
class Order
{
    #[ORM\ManyToOne(targetEntity: Customer::class, inversedBy: 'orders')]
    #[ORM\JoinColumn(nullable: false, onDelete: 'RESTRICT')]
    private Customer $customer;

    public function getCustomer(): Customer { return $this->customer; }
}

#[ORM\Entity]
class Customer
{
    /** @var Collection<int, Order> */
    #[ORM\OneToMany(targetEntity: Order::class, mappedBy: 'customer', fetch: 'EXTRA_LAZY')]
    private Collection $orders;

    public function __construct()
    {
        $this->orders = new ArrayCollection();
    }

    /** @return Collection<int, Order> */
    public function getOrders(): Collection { return $this->orders; }
}
```

### Rules

- **Owning side** = the entity with `ManyToOne` (carries the FK column).
- **Inverse side** = the entity with `OneToMany`. Use `inversedBy:` ↔ `mappedBy:` to link them.
- **`fetch: 'EXTRA_LAZY'`** on the collection if it can grow large — enables `count()` / `contains()` / `slice()` without loading.
- **`onDelete: 'RESTRICT'`** (DB-level) prevents orphaning. `cascade: ['remove']` (ORM-level) cascades the delete — **use with care**, mainly for owning aggregates.

## 3. ManyToMany

```php
#[ORM\Entity]
class Article
{
    /** @var Collection<int, Tag> */
    #[ORM\ManyToMany(targetEntity: Tag::class, inversedBy: 'articles')]
    #[ORM\JoinTable(name: 'article_tag')]
    private Collection $tags;
}

#[ORM\Entity]
class Tag
{
    /** @var Collection<int, Article> */
    #[ORM\ManyToMany(targetEntity: Article::class, mappedBy: 'tags')]
    private Collection $articles;
}
```

If the join table needs **extra columns** (e.g. `added_at`, `added_by`), don't use `ManyToMany` — introduce an explicit `ArticleTag` entity with two `ManyToOne` to `Article` and `Tag`.

## 4. OneToOne

```php
#[ORM\Entity]
class User
{
    #[ORM\OneToOne(targetEntity: UserPreference::class, mappedBy: 'user', cascade: ['persist', 'remove'])]
    private ?UserPreference $preference = null;
}

#[ORM\Entity]
class UserPreference
{
    #[ORM\OneToOne(targetEntity: User::class, inversedBy: 'preference')]
    #[ORM\JoinColumn(nullable: false, unique: true)]
    private User $user;
}
```

`cascade: ['persist', 'remove']` is acceptable on aggregate roots (User owns Preference).

## 5. Cascade operations

| Cascade | Effect |
|---|---|
| `persist` | When parent is persisted, children too. Useful when adding children via the parent (`$user->addOrder($order)` + `$em->persist($user)`). |
| `remove` | When parent is removed, children too. **Dangerous** on `ManyToOne` (delete user → delete all orders ?). OK on `OneToOne` aggregates. |
| `refresh` / `detach` / `merge` | Rarely used in modern code. |

Default = **no cascade**. Add only when the relation has a clear ownership semantic.

## 6. Orphan removal

```php
#[ORM\OneToMany(
    targetEntity: OrderItem::class,
    mappedBy: 'order',
    orphanRemoval: true,    // ← when removed from collection, the row is deleted
    cascade: ['persist'],
)]
private Collection $items;
```

When you do `$order->getItems()->removeElement($item)`, `orphanRemoval: true` ensures the row is deleted on flush. Without it, you get an orphan row with `order_id = NULL` (or FK violation).

## 7. Fetch mode strategy

| Use case | Recommendation |
|---|---|
| Default (small collection, accessed often) | `fetch: 'LAZY'` (default) |
| Large collection rarely accessed | `fetch: 'EXTRA_LAZY'` — methods like `count()` issue a single COUNT query, `contains()` issues an EXISTS |
| Always loaded together | Per-property `#[ApiProperty(fetchEager: true)]` (API Platform) OR `addSelect('a')` in the repository — NEVER `fetch: 'EAGER'` at mapping level for collections |
| Read-only batch processing | `setHint(Query::HINT_READ_ONLY, true)` in the repository query |

Cf. `gerard:doctrine-fetch-modes` for the deeper pattern.

## 8. Indexes

```php
#[ORM\Entity]
#[ORM\Index(columns: ['email'], name: 'idx_user_email')]
#[ORM\Index(columns: ['created_at'], name: 'idx_user_created')]
#[ORM\Index(columns: ['is_active', 'deleted_at'], name: 'idx_user_active')]
#[ORM\UniqueConstraint(name: 'uniq_user_email', columns: ['email'])]
class User { /* ... */ }
```

**Always index** :
- Foreign key columns (Doctrine adds these automatically on `ManyToOne`)
- Columns filtered in API Platform `parameters`
- Columns used in `WHERE`, `ORDER BY`, `JOIN`
- Composite indexes for common filter combinations

Cf. `gerard:api-platform-filters` for the API-side index requirement.

## 9. Self-referencing relations (tree / hierarchy)

```php
#[ORM\Entity]
class Category
{
    #[ORM\ManyToOne(targetEntity: self::class, inversedBy: 'children')]
    private ?Category $parent = null;

    /** @var Collection<int, Category> */
    #[ORM\OneToMany(targetEntity: self::class, mappedBy: 'parent')]
    private Collection $children;
}
```

For tree traversal performance, consider Materialized Path or Nested Set patterns (vs naive recursive queries).

## 10. Polymorphic relations — Single Table Inheritance

```php
#[ORM\Entity]
#[ORM\InheritanceType('SINGLE_TABLE')]
#[ORM\DiscriminatorColumn(name: 'type', type: 'string')]
#[ORM\DiscriminatorMap(['user' => User::class, 'admin' => AdminUser::class])]
abstract class AbstractAccount { /* shared columns */ }

#[ORM\Entity]
class User extends AbstractAccount { /* ... */ }

#[ORM\Entity]
class AdminUser extends AbstractAccount { /* + admin columns */ }
```

Use sparingly. Composition often beats inheritance — prefer `User` with an `AdminProfile` relation if the divergence is data, not behavior.

## 11. Anti-patterns

- ❌ `fetch: 'EAGER'` at the mapping level on a collection — every query loads the collection → N+1 cascades silently
- ❌ `cascade: ['remove']` on a `ManyToOne` to a "parent" entity (deleting a child shouldn't delete the parent !)
- ❌ Missing `orphanRemoval: true` on aggregate children when you mutate the collection (`$order->removeItem($item)` should delete)
- ❌ `$em->getRepository(X::class)` in a service — inject the repository via constructor
- ❌ Forgetting `inversedBy` ↔ `mappedBy` pair — Doctrine treats them as independent → silent data drift
- ❌ Adding an index after seeing slow queries instead of when designing — every filtered column gets an index at design time

## 12. Validation commands

```bash
# Verify entity ↔ DB schema parity
php bin/console doctrine:schema:validate

# Show entity mapping
php bin/console doctrine:mapping:info

# Profile queries (dev profiler)
# Then check the Doctrine panel for N+1 detection
```

## 13. Related skills

- `gerard:doctrine-migrations` — generate the migration from your relation
- `gerard:doctrine-fetch-modes` — fetch tuning, force_eager trap
- `gerard:doctrine-transactions` — atomic multi-entity writes
- `gerard:api-platform-resources` — IRI-only rule (no scalar FK in DTO)
- `gerard:api-platform-identifiers` — UUID v7 / ULID strategy for relation keys
