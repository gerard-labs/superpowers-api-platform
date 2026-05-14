# API Platform 4.3 — Versioning (reference)

## 1. Strategy 1 — URI versioning (recommended for breaking changes)

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use Symfony\Component\Serializer\Attribute\Groups;

#[ApiResource(
    uriTemplate: '/v1/products',
    shortName:   'Product',
    operations: [
        new GetCollection(uriTemplate: '/v1/products'),
        new Get(uriTemplate: '/v1/products/{id}'),
    ],
    normalizationContext: ['groups' => ['product:read:v1']],
)]
#[ApiResource(
    uriTemplate: '/v2/products',
    shortName:   'ProductV2',
    operations: [
        new GetCollection(uriTemplate: '/v2/products'),
        new Get(uriTemplate: '/v2/products/{id}'),
    ],
    normalizationContext: ['groups' => ['product:read:v2']],
)]
class Product
{
    #[Groups(['product:read:v1', 'product:read:v2'])]
    private ?int $id = null;

    #[Groups(['product:read:v1', 'product:read:v2'])]
    private string $name;

    // v1: price in cents, integer
    #[Groups(['product:read:v1'])]
    private int $price;

    // v2: price as Money object
    #[Groups(['product:read:v2'])]
    private Money $priceAmount;

    // v2 only: new field
    #[Groups(['product:read:v2'])]
    private ?string $sku = null;
}
```

---

## 2. Strategy 2 — Separate DTOs per version

```php
// src/Dto/V1/ProductOutput.php
namespace App\Dto\V1;

final readonly class ProductOutput
{
    public function __construct(
        public int    $id,
        public string $name,
        public int    $price,   // cents
    ) {}
}

// src/Dto/V2/ProductOutput.php
namespace App\Dto\V2;

final readonly class ProductOutput
{
    public function __construct(
        public int     $id,
        public string  $name,
        public array   $price,  // {amount: 1999, currency: 'EUR'}
        public ?string $sku,
        public array   $metadata,
    ) {}
}
```

```php
#[ApiResource(
    uriTemplate: '/v1/products',
    operations: [
        new Get(
            uriTemplate: '/v1/products/{id}',
            output:      ProductOutputV1::class,
            provider:    ProductV1Provider::class,
        ),
    ],
)]
#[ApiResource(
    uriTemplate: '/v2/products',
    operations: [
        new Get(
            uriTemplate: '/v2/products/{id}',
            output:      ProductOutputV2::class,
            provider:    ProductV2Provider::class,
        ),
    ],
)]
class Product { /* ... */ }
```

---

## 3. Strategy 3 — Header-based versioning

```php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\RequestStack;

final class VersionedProductProvider implements ProviderInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.item_provider')]
        private ProviderInterface $itemProvider,
        private RequestStack $requestStack,
    ) {}

    public function provide(Operation $operation, array $uriVariables = [], array $context = []): object|array|null
    {
        $product = $this->itemProvider->provide($operation, $uriVariables, $context);
        if (!$product) {
            return null;
        }

        $version = $this->requestStack->getCurrentRequest()?->headers->get('X-API-Version', 'v2');

        return match ($version) {
            'v1'    => $this->toV1($product),
            default => $this->toV2($product),
        };
    }
}
```

Cf. `gerard:api-platform-state-providers` for the underlying pattern.

---

## 4. Group-based versioning (additive minor changes only)

For a pure field addition: a new group `product:read:v2` without changing the URL. The legacy client still sees the same shape; only clients opting into the new group see the new field.

**Strict rule**: never to remove or rename a field. That always requires a new version (URI or DTO).

---

## 5. Marking an operation as deprecated (4.x attribute)

> ⚠️ `openapiContext: ['deprecated' => true]` (3.x) is deprecated. Use `openapi: new \ApiPlatform\OpenApi\Model\Operation(deprecated: true)`. Rector script available: <https://github.com/lyrixx/rector-apip-openapi>.

```php
use ApiPlatform\Metadata\Get;
use ApiPlatform\OpenApi\Model;

new Get(
    uriTemplate:       '/v1/products/{id}',
    deprecationReason: 'Use /v2/products/{id} instead. Will be removed in 2025.',
    sunset:            '2025-12-31',
    openapi:           new Model\Operation(deprecated: true),
)
```

Generated effects:

- OpenAPI marks the operation as `deprecated: true`.
- API Platform emits a `Deprecation: true` header.
- API Platform emits a `Sunset: …` header (RFC 8594) when `sunset:` is set.

---

## 6. Custom `Sunset` / `Link: rel="successor-version"` subscriber

For finer control (e.g. dynamic `Link` based on the path), add a `KernelEvents::RESPONSE` subscriber:

```php
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

final class DeprecationSubscriber implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [KernelEvents::RESPONSE => 'onResponse'];
    }

    public function onResponse(ResponseEvent $event): void
    {
        $request = $event->getRequest();
        $path    = $request->getPathInfo();

        if (str_starts_with($path, '/api/v1/')) {
            $response = $event->getResponse();
            $response->headers->set('Sunset',      'Sat, 01 Jan 2025 00:00:00 GMT');
            $response->headers->set('Deprecation', 'true');
            $response->headers->set(
                'Link',
                '</api/v2' . substr($path, 7) . '>; rel="successor-version"',
            );
        }
    }
}
```

This is one of the legitimate cases for keeping a Symfony listener — it modifies the final `Response` (cf. `gerard:api-platform-resources` §9).

---

## 7. Documenting the diff in the DTO header

A short comment at the top of each v2 DTO lists the diffs from v1:

```php
/**
 * Product representation (API v2).
 *
 * Changes from v1:
 * - `price` is now an object with `amount` and `currency`
 * - Added `sku` field
 * - Added `metadata` field
 * - Removed `priceInCents` (use `price.amount`)
 */
final readonly class ProductOutputV2 { /* ... */ }
```

---

## 8. Routing configuration

```yaml
# config/routes/api_platform.yaml
api_platform:
    resource: .
    type:     api_platform
    prefix:   /api
```

URIs combined with the resource-level `uriTemplate` then yield `/api/v1/...` and `/api/v2/...`.

---

## 9. Testing multiple versions

```php
public function test_v1_returns_legacy_format(): void
{
    $product = ProductFactory::createOne(['price' => 1999]);

    $response = $this->client->request('GET', '/api/v1/products/' . $product->getId());

    $this->assertResponseIsSuccessful();
    $data = $response->toArray();
    $this->assertIsInt($data['price']);
    $this->assertEquals(1999, $data['price']);
}

public function test_v2_returns_new_format(): void
{
    $product = ProductFactory::createOne(['price' => 1999]);

    $response = $this->client->request('GET', '/api/v2/products/' . $product->getId());

    $this->assertResponseIsSuccessful();
    $data = $response->toArray();
    $this->assertIsArray($data['price']);
    $this->assertEquals(1999,  $data['price']['amount']);
    $this->assertEquals('EUR', $data['price']['currency']);
}
```

Cf. `gerard:api-platform-tests` for the full testing posture.

---

## 10. Best practices

1. **URI versioning for breaking changes** — clearest for consumers.
2. **Groups for additive minor changes** — no new version required.
3. **Announce a sunset date** — leave consumers time to migrate.
4. **Keep a per-version changelog** in the DTO header.
5. **Test every active version** — no silent regression.
6. **Limit active versions** — 2 to 3 maximum.
7. **Use the Rector migration script** when bulk-converting `openapiContext` → `openapi: new Model\Operation(...)`.

---

## 11. Related skills

- `gerard:api-platform-resources` — `uriTemplate`, operation declaration.
- `gerard:api-platform-dto-resources` — DTOs per version.
- `gerard:api-platform-state-providers` — header-versioned providers.
- `gerard:api-platform-openapi` — `Model\Operation`, Scalar UI, OpenAPI customization.
- `gerard:api-platform-tests` — multi-version functional tests.
- `gerard:api-platform-upgrade` — bulk migration from `openapiContext` to the modern attribute.
