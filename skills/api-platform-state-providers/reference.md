# API Platform 4.3 — State Providers (reference)

## 1. Role

Transform the data source (Doctrine entities, read model, external API, search engine, cache) into the API representation (entity or Output DTO). The Provider is the read pipeline; the Processor (separate skill) is the write pipeline.

## 2. Scaffolding

```bash
php bin/console make:state-provider           # generates a skeleton in src/State/
```

## 3. Core rules

- **Always inject a repository or a service**, never the `EntityManagerInterface` directly inside a Provider.
- **No hard-coded role checks** in a Provider — use `security:` on the operation, or a voter.
- **Return `null` for a missing item** — API Platform will emit a 404.
- **Decorate the Doctrine default Provider** when you only need to add a transformation (lightweight, focused).
- **Multiple Providers are allowed** for the same resource — "the first able to provide the data is used" — autoconfigured via the `api_platform.state_provider` tag.
- **Deprecated interfaces 4.2 → removed 5.0**: `SerializerAwareProviderInterface`, `SerializableProvider`. If you still implement them, remove them.
- **Discriminate collection vs item** with `CollectionOperationInterface` when a single Provider covers both.

---

## 4. Decorating the native Doctrine Provider (modern pattern)

Inject the default item / collection providers via `#[Autowire(service: ...)]` — simpler than `#[AsDecorator]` and is the official pattern in 4.x.

```php
use ApiPlatform\Metadata\CollectionOperationInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

final readonly class ProductProvider implements ProviderInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.item_provider')]
        private ProviderInterface $itemProvider,
        #[Autowire(service: 'api_platform.doctrine.orm.state.collection_provider')]
        private ProviderInterface $collectionProvider,
    ) {}

    public function provide(Operation $op, array $uriVars = [], array $ctx = []): mixed
    {
        if ($op instanceof CollectionOperationInterface) {
            $items = $this->collectionProvider->provide($op, $uriVars, $ctx);
            return $this->transformCollection($items);
        }

        $entity = $this->itemProvider->provide($op, $uriVars, $ctx);
        return $entity ? ProductOutput::fromEntity($entity) : null;
    }

    private function transformCollection(iterable $items): iterable
    {
        // Map each entity → DTO if needed. For paginators, wrap in TraversablePaginator.
        // ...
    }
}
```

Wire it on the operation:

```php
new Get(provider: ProductProvider::class),
new GetCollection(provider: ProductProvider::class),
```

### Preserving the paginator

If you transform a collection of entities into DTOs, **preserve the paginator wrapper** so that pagination metadata (`totalItems`, `view`, etc.) remains correct:

```php
use ApiPlatform\State\Pagination\TraversablePaginator;
use ApiPlatform\State\Pagination\PartialPaginatorInterface;

private function transformCollection(iterable $items): iterable
{
    if ($items instanceof PartialPaginatorInterface) {
        $mapped = array_map(fn($e) => ProductOutput::fromEntity($e), iterator_to_array($items));
        return new TraversablePaginator(
            new \ArrayIterator($mapped),
            $items->getCurrentPage(),
            $items->getItemsPerPage(),
            method_exists($items, 'getTotalItems') ? $items->getTotalItems() : count($mapped),
        );
    }
    return array_map(fn($e) => ProductOutput::fromEntity($e), iterator_to_array($items));
}
```

---

## 5. Header-versioned Provider (full example)

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

Cf. `gerard:api-platform-versioning` for the broader versioning strategies.

---

## 6. Common mistakes to avoid

- **N+1 inside the Provider.** If you iterate over a collection and trigger lazy loads, expect a query storm. Add a join fetch in the repository, or project a DTO directly via DQL `NEW App\Dto\ProductListItem(...)`. See `gerard:doctrine-fetch-modes`.
- **Security in the Provider.** Use the operation's `security:` expression or a voter. The Provider must not know "if admin then …".
- **Persistence in the Provider.** A Provider reads; it never writes. Even mutating a "lastViewedAt" should be done elsewhere (Processor, listener on response).
- **Forgetting `null` returns.** Returning a placeholder instead of `null` for a missing item breaks API Platform's automatic 404.

---

## 7. Custom Parameter Providers (4.3 — separate concept)

API Platform 4.3 also introduces **Parameter Providers** that transform a `QueryParameter` value before it reaches the filters. They are not "State Providers" but you may see them in the codebase under `src/State/`:

- `IriConverterParameterProvider` — convert `?user=/users/42` into the `User` entity.
- `ReadLinkParameterProvider` — read a parent link from the URI template.
- Custom (implement `ApiPlatform\State\ParameterProviderInterface`) — e.g. dynamic group injection based on a `?view=` parameter.

Those belong to `gerard:api-platform-filters` (the parameters / QueryParameter pipeline), not to this skill. Cross-referenced for clarity.

---

## 8. Validation commands

```bash
php bin/console debug:router | grep api
./vendor/bin/phpunit --filter=Provider
./vendor/bin/paratest -p8

# Confirm there is no legacy interface left
rg "SerializerAwareProviderInterface|SerializableProvider" src/ && echo "Legacy interfaces still present"
```

---

## 9. Related skills

- `gerard:api-platform-resources` — operations and IRI-only rule.
- `gerard:api-platform-state-processors` — write pipeline.
- `gerard:api-platform-dto-resources` — DTOs returned by Providers (Object Mapper alternative).
- `gerard:api-platform-versioning` — header / URI / DTO versioning.
- `gerard:doctrine-fetch-modes` — avoiding N+1 in queries the Provider triggers.
- `gerard:api-platform-upgrade` — to migrate code that still uses `SerializerAwareProviderInterface` or `SerializableProvider`.
