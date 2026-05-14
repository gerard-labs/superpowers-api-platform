# API Platform 4.3 — Resource & Operation Mutators (reference)

> 🆕 **API Platform 4.3** introduces `#[AsResourceMutator]` and `#[AsOperationMutator]` to dynamically modify metadata at compile time (not runtime). Use cases: prefix every route of a resource, inject a serialization group conditionally, apply uniform auth.
>
> Source: <https://api-platform.com/docs/core/operations/>.

## 1. Resource Mutator — change the whole resource

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\AsResourceMutator;
use ApiPlatform\Metadata\Operations;
use ApiPlatform\Metadata\Resource\ResourceMutatorInterface;

#[AsResourceMutator(resourceClass: Book::class)]
final class ApiPrefixMutator implements ResourceMutatorInterface
{
    public function __invoke(ApiResource $resource): ApiResource
    {
        $operations = new Operations();
        foreach ($resource->getOperations() as $name => $operation) {
            $operations->add($name, $operation->withRoutePrefix('/api/v1'));
        }
        return $resource->withOperations($operations);
    }
}
```

This adds the `/api/v1` prefix to every operation of `Book` — without touching the `#[ApiResource]` attribute. Useful when:

- A team-wide policy says "every public resource is prefixed with `/api/v1`".
- The prefix logic depends on a build-time signal (e.g. a config value, an env-based feature flag).

---

## 2. Operation Mutator — change one operation

```php
use ApiPlatform\Metadata\AsOperationMutator;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Resource\OperationMutatorInterface;

#[AsOperationMutator(operationName: '_api_Book_get_collection')]
final class BookCollectionMutator implements OperationMutatorInterface
{
    public function __invoke(Operation $operation): Operation
    {
        $context = $operation->getNormalizationContext() ?? [];
        $context['groups'][] = 'book:enriched';
        return $operation->withNormalizationContext($context);
    }
}
```

This adds the `book:enriched` group to the `GET /api/books` collection operation. Useful for:

- Conditionally enriching a specific operation without polluting the entity / DTO attributes.
- Composing build-time policies (e.g. "every collection operation gets the `enriched` group when feature X is enabled at build time").

### Operation names

API Platform names operations following the convention `_api_<ShortName>_<operation>`:

- `_api_Book_get`
- `_api_Book_get_collection`
- `_api_Book_post`
- `_api_Book_put`
- `_api_Book_patch`
- `_api_Book_delete`

For custom-named operations (`new Post(name: 'publish', uriTemplate: '/books/{id}/publish')`), the name becomes `_api_Book_publish`.

Pin these in a constant when referenced in multiple places:

```php
final class BookOperations
{
    public const GET_COLLECTION = '_api_Book_get_collection';
    public const PUBLISH        = '_api_Book_publish';
}
```

---

## 3. When to use a Mutator vs a Context Builder

| Criterion | Mutator | Context Builder |
|---|---|---|
| Decision time | **Build time** (cache, compile) | **Runtime** (every request) |
| Use case | "Every operation of this resource gets X" | "Add group Y if the user is admin" |
| Cost | Zero runtime | Cost per request |
| Granularity | Resource or named operation | Per-request, per-user, per-locale, per-header |

**Rule**: anything that can be decided at build time → Mutator (free perf). Runtime decisions → Context Builder (cf. `gerard:api-platform-serialization` §15-16).

---

## 4. Worked examples

### Apply a default JWT security policy to every write operation

```php
#[AsResourceMutator(resourceClass: AdminResource::class)]
final class AdminWriteSecurityMutator implements ResourceMutatorInterface
{
    public function __invoke(ApiResource $resource): ApiResource
    {
        $operations = new Operations();
        foreach ($resource->getOperations() as $name => $op) {
            if ($op instanceof \ApiPlatform\Metadata\Post
                || $op instanceof \ApiPlatform\Metadata\Put
                || $op instanceof \ApiPlatform\Metadata\Patch
                || $op instanceof \ApiPlatform\Metadata\Delete) {
                $op = $op->withSecurity("is_granted('ROLE_ADMIN')");
            }
            $operations->add($name, $op);
        }
        return $resource->withOperations($operations);
    }
}
```

### Add a global cache header to every read operation

```php
#[AsResourceMutator(resourceClass: PublicCatalog::class)]
final class CachePolicyMutator implements ResourceMutatorInterface
{
    public function __invoke(ApiResource $resource): ApiResource
    {
        $operations = new Operations();
        foreach ($resource->getOperations() as $name => $op) {
            if ($op instanceof \ApiPlatform\Metadata\Get
                || $op instanceof \ApiPlatform\Metadata\GetCollection) {
                $op = $op->withCacheHeaders(['max_age' => 3600, 'shared_max_age' => 86400]);
            }
            $operations->add($name, $op);
        }
        return $resource->withOperations($operations);
    }
}
```

---

## 5. Validation

After adding a Mutator:

```bash
php bin/console debug:router | grep api          # verify route prefixes
php bin/console api:openapi:export --yaml         # verify the resulting OpenAPI
./vendor/bin/phpunit --filter=Api                 # functional tests still green
```

Mutators run at compile time and are cached — clear the cache after editing:

```bash
php bin/console cache:clear --env=prod
```

---

## 6. Related skills

- `gerard:api-platform-resources` — operation declaration site.
- `gerard:api-platform-serialization` §15-16 — Context Builder vs Mutator decision.
- `gerard:api-platform-security` — apply uniform `security` via a Mutator instead of repeating it.
- `gerard:api-platform-performance` — `cacheHeaders` applied uniformly via a Mutator.
- `gerard:api-platform-openapi` — verify the result with `api:openapi:export`.
