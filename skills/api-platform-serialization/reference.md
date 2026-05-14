# API Platform 4.3 — Serialization (reference)

## 1. Group conventions

- Name groups as `entity:operation` — `user:list`, `user:read`, `user:create`, `user:update`.
- **Read ≠ write**: never reuse the same group across directions.
- **Write-only groups** for sensitive fields (`password` → `user:create` only).
- **Read-only groups** for derived fields (`createdAt` → `user:read` only).

```php
use Symfony\Component\Serializer\Attribute\Groups;

class User
{
    #[Groups(['user:list', 'user:read'])]
    private ?int $id = null;

    #[Groups(['user:list', 'user:read', 'user:create', 'user:update'])]
    private string $name;

    #[Groups(['user:read', 'user:create'])]
    private string $email; // not updatable, not in list

    #[Groups(['user:create'])]
    private string $password; // write-only

    #[Groups(['user:read'])]
    private \DateTimeImmutable $createdAt; // read-only, not in list
}
```

---

## 2. Controlling nested serialization

On a relation, the child entity only exposes properties whose group is included in the parent context → the list stays light.

For collections, expose the bare minimum (id + label) in `user:read`, and require a dedicated request for the full detail.

---

## 3. `MaxDepth` — break circular references

Activate `enable_max_depth` on the normalization context **and** annotate the at-risk relations.

```php
use Symfony\Component\Serializer\Attribute\MaxDepth;

#[ApiResource(normalizationContext: ['groups' => ['post:read'], 'enable_max_depth' => true])]
class Post
{
    #[MaxDepth(1)]
    #[Groups(['post:read'])]
    private User $author;
}
```

---

## 4. `#[Ignore]` — never expose

For fields that must never appear in any payload (password hash, reset token, internal secret):

```php
use Symfony\Component\Serializer\Attribute\Ignore;

class User
{
    #[Ignore] private string $password;
    #[Ignore] private string $resetToken;
}
```

---

## 5. Forcing a relation to IRI (no embed)

By default, API Platform may embed a related resource. Force the IRI (consistent with the IRI-only rule from `gerard:api-platform-resources`) — useful for self-referencing entities or to avoid bloated payloads:

```php
use ApiPlatform\Metadata\ApiProperty;

class Order
{
    #[ApiProperty(readableLink: false, writableLink: false)]
    private Customer $customer;   // always serialized as "/api/customers/..."
}
```

- `readableLink: false` → output as IRI.
- `writableLink: false` → input as IRI (no nested object accepted).

---

## 6. Native `BackedEnum`

PHP 8.1+ `BackedEnum` is supported natively:

- Serialized as `string` (the backing scalar).
- Documented as `enum: [...]` in OpenAPI.
- Persistable via Doctrine `#[ORM\Column(enumType: OrderStatus::class)]`.
- Filterable via `BackedEnumFilter` (cf. `gerard:api-platform-filters`).

```php
enum OrderStatus: string {
    case Draft     = 'draft';
    case Processed = 'processed';
}

class Order {
    #[Groups(['order:read'])]
    private OrderStatus $status;
}
```

---

## 7. Custom Normalizer — computed fields

Decorate the format-specific normalizer (`api_platform.jsonld.normalizer.item` for JSON-LD; `api_platform.hal.normalizer.item` for HAL; `api_platform.serializer.normalizer.item` for plain JSON). Use the `ALREADY_CALLED` pattern to avoid infinite recursion.

```php
use App\Entity\User;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\Serializer\Normalizer\NormalizerInterface;

final class UserNormalizer implements NormalizerInterface
{
    private const ALREADY_CALLED = 'USER_NORMALIZER_ALREADY_CALLED';

    public function __construct(
        #[Autowire(service: 'api_platform.jsonld.normalizer.item')]
        private NormalizerInterface $normalizer,
    ) {}

    public function normalize(mixed $object, ?string $format = null, array $context = []): array
    {
        $context[self::ALREADY_CALLED] = true;
        /** @var User $object */
        $data = $this->normalizer->normalize($object, $format, $context);

        $data['fullName']   = $object->getFirstName() . ' ' . $object->getLastName();
        $data['postCount'] = $object->getPosts()->count();
        $data['isVerified'] = $object->getVerifiedAt() !== null;

        return $data;
    }

    public function supportsNormalization(mixed $data, ?string $format = null, array $context = []): bool
    {
        return !isset($context[self::ALREADY_CALLED]) && $data instanceof User;
    }

    public function getSupportedTypes(?string $format): array
    {
        return [User::class => false]; // false means "non-cacheable supports decision"
    }
}
```

---

## 8. Conditional Normalizer — role-aware fields

Inject `Symfony\Bundle\SecurityBundle\Security` to reveal fields only to admins or the owner. Never expose an admin-only field without an `isGranted` guard.

```php
use Symfony\Bundle\SecurityBundle\Security;

final class PostNormalizer implements NormalizerInterface
{
    private const ALREADY_CALLED = 'POST_NORMALIZER_ALREADY_CALLED';

    public function __construct(
        #[Autowire(service: 'api_platform.jsonld.normalizer.item')]
        private NormalizerInterface $normalizer,
        private Security $security,
    ) {}

    public function normalize(mixed $object, ?string $format = null, array $context = []): array
    {
        $context[self::ALREADY_CALLED] = true;
        $data = $this->normalizer->normalize($object, $format, $context);

        if ($this->security->isGranted('ROLE_ADMIN')) {
            $data['internalNotes']    = $object->getInternalNotes();
            $data['moderationStatus'] = $object->getModerationStatus();
        }

        if ($this->security->getUser() === $object->getAuthor()) {
            $data['analytics'] = [
                'views'      => $object->getViewCount(),
                'engagement' => $object->getEngagementRate(),
            ];
        }

        return $data;
    }

    public function supportsNormalization(mixed $data, ?string $format = null, array $context = []): bool
    {
        return !isset($context[self::ALREADY_CALLED]) && $data instanceof Post;
    }

    public function getSupportedTypes(?string $format): array
    {
        return [Post::class => false];
    }
}
```

---

## 9. `#[Context]` — per-property format

Apply a serialization format to a single property without touching the global context.

```php
use Symfony\Component\Serializer\Annotation\Context;
use Symfony\Component\Serializer\Normalizer\DateTimeNormalizer;

class Event
{
    #[Context([DateTimeNormalizer::FORMAT_KEY => 'Y-m-d'])]
    public ?\DateTimeImmutable $startDate = null;

    #[Context(
        context: [DateTimeNormalizer::FORMAT_KEY => \DateTime::RFC3339_EXTENDED],
        groups:  ['extended'],
    )]
    public ?\DateTimeImmutable $publishedAt = null;
}
```

`normalizationContext:` and `denormalizationContext:` keys are also supported to differentiate input vs output behavior.

---

## 10. Name converter — `firstName` ↔ `first_name`

```yaml
# config/services.yaml
services:
    Symfony\Component\Serializer\NameConverter\CamelCaseToSnakeCaseNameConverter: ~

# config/packages/api_platform.yaml
api_platform:
    name_converter: 'Symfony\Component\Serializer\NameConverter\CamelCaseToSnakeCaseNameConverter'
```

`firstName` in PHP becomes `first_name` in the API, and vice-versa.

---

## 11. Embedding the JSON-LD `@context`

By default, the `@context` field references an external URL (`{"@context": "/contexts/Book"}`) — clients need a second HTTP call. Inline it:

```php
#[ApiResource(normalizationContext: ['jsonld_embed_context' => true])]
class Book { /* ... */ }
```

Useful for clients that consume the spec without dereferencing the `@context` URI.

---

## 12. `gen_id` — control `@id` generation (4.3)

```yaml
api_platform:
    defaults:
        normalization_context:
            gen_id: false       # suppress @id on nested objects (resources only)
```

Reduces payload size when nested objects don't need an addressable identifier.

---

## 13. `skip_null_values` (default 4.x)

```yaml
api_platform:
    defaults:
        normalization_context:
            skip_null_values: true   # 4.x default — no more "field": null in output
```

Verify in tests that you assert presence, not equality with `null`. Use `assertArrayHasKey` / `assertArrayNotHasKey` to capture the intent.

---

## 14. `getValues()` on `ArrayCollection`

Doctrine sometimes returns collections indexed by entity IDs. JSON does not preserve such keys cleanly — the response may contain an object instead of a flat array. Normalize via `getValues()`:

```php
public function getCars(): array
{
    return $this->cars->getValues();
}
```

---

## 15. Context Builder — dynamic groups

Decorate `api_platform.serializer.context_builder` to add a group at runtime based on the request.

```php
use ApiPlatform\Serializer\SerializerContextBuilderInterface;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Security\Core\Authorization\AuthorizationCheckerInterface;
use Symfony\Component\DependencyInjection\Attribute\AutowireDecorated;

final class UserContextBuilder implements SerializerContextBuilderInterface
{
    public function __construct(
        #[AutowireDecorated]
        private SerializerContextBuilderInterface $decorated,
        private AuthorizationCheckerInterface $authChecker,
    ) {}

    public function createFromRequest(Request $request, bool $normalization, ?array $attributes = null): array
    {
        $context = $this->decorated->createFromRequest($request, $normalization, $attributes);

        if ($normalization && $this->authChecker->isGranted('ROLE_ADMIN')) {
            $context['groups'][] = 'admin:read';
        }

        return $context;
    }
}
```

```yaml
services:
    App\Serializer\UserContextBuilder:
        decorates: 'api_platform.serializer.context_builder'
```

---

## 16. Context Builder vs Resource/Operation Mutator (4.3)

| Criterion | Mutator (`#[AsResourceMutator]` / `#[AsOperationMutator]`) | Context Builder |
|---|---|---|
| Decision time | **Build time** (cached) | **Runtime** (per request) |
| Use case | "Every operation on Book gets group X" | "Add admin:read if the user is admin" |
| Cost | Zero at request time | Cost on every request |
| Granularity | Per resource or per named operation | Per request, per user, per context |

**Rule of thumb**: if the decision can be made at build time, prefer a **Mutator** — see `gerard:api-platform-mutators`. Use the Context Builder only when the decision depends on the request itself (auth state, locale, header).

---

## 17. Cross-cutting rules

1. **Consistent groups**: `entity:operation` convention everywhere.
2. **Separate read / write** strictly.
3. **Limit depth** with `MaxDepth` whenever there is a risk of cycles.
4. **Computed fields in a Normalizer**, never in the entity itself.
5. **Dynamic groups via Context Builder** for runtime decisions; **Mutator** for build-time decisions.
6. **Every group affects the OpenAPI schema** — document each combination if it impacts the contract.

---

## 18. Related skills

- `gerard:api-platform-resources` — IRI-only rule, operation declarations.
- `gerard:api-platform-dto-resources` — separate Input / Output groups via DTOs.
- `gerard:api-platform-security` — property-level security via `#[ApiProperty(security: ...)]`.
- `gerard:api-platform-mutators` — build-time alternative to the Context Builder.
- `gerard:api-platform-openapi` — how groups surface in the generated spec.
- `gerard:value-objects-and-dtos` — BackedEnum / VO patterns.
