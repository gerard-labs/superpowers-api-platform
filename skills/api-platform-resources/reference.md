# API Platform 4.3 — Resources & operations (reference)

## 1. Posture

### Four-step default workflow

1. **Define** the operation boundary — which operation, which payload, which invariants.
2. **Implement** the resource / DTO / provider / processor with explicit mapping.
3. **Apply** operation-specific validation and security.
4. **Validate** the functional behavior across happy and negative paths.

### Always-on guardrails

- **Explicit, version-aware API contract.** No silent behavior change between versions.
- **Never implicitly expose internal entity fields.** Groups or DTO — pick one, be explicit.
- **No drift between OpenAPI and runtime.** The doc must reflect what the API actually returns.
- **Minimal but correct scope.** Change as little as possible without breaking the contract.
- **Always test the negative path** — invalid payload, forbidden actor, boundary values, 404, partial retries on async.

### Pre-modification detection

- Read `composer.lock` → `api-platform/symfony` (or `api-platform/core` for legacy 3.x). The session hook surfaces the version automatically; if it is < 4.3, escalate to `gerard:api-platform-upgrade` before touching anything.
- Inspect `config/packages/api_platform.yaml` for legacy flags that must be absent in 4.x:
  - `event_listeners_backward_compatibility_layer`
  - `keep_legacy_inflector`
  - `validator.legacy_validation_exception`
- Scan `src/ApiResource/` and `src/Entity/` for existing `#[ApiResource]` attributes.
- Identify the project's pattern: **entity-as-resource** vs **DTO-backed resource**.

---

## 2. Resource-First Design (Resource ≠ Entity)

| Aspect | Resource (`GetOrderResource`) | Entity (`Order`) |
|---|---|---|
| Role | External contract (HTTP, JSON-LD) | Internal persisted model |
| Stability | Must stay stable for clients | Free to evolve |
| DB coupling | None | Total (ORM) |
| Owner | API team | Domain team |

One entity can back several resources (different views). One resource can aggregate several entities.

### When `stateOptions` is acceptable

`stateOptions: new Options(entityClass: Foo::class)` shortcut auto-binds Resource ↔ Entity. Only use it when:

- The Resource and the Entity have **exactly** the same structure.
- No specific logic (caching, aggregation, filtering) is required.
- The entity is unlikely to diverge from the contract.

Otherwise → explicit **State Provider** to preserve separation of concerns.

---

## 3. Declaring resources and operations

### Always use PHP attributes

- Prefer `#[ApiResource]` over YAML / XML mapping.
- Declare each operation explicitly: `Get`, `GetCollection`, `Post`, `Put`, `Patch`, `Delete`. No implicit magic.
- Import nominally from `ApiPlatform\Metadata\…`.

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\Put;

#[ApiResource(
    operations: [
        new GetCollection(normalizationContext: ['groups' => ['product:list']]),
        new Get(normalizationContext: ['groups' => ['product:read']]),
        new Post(denormalizationContext: ['groups' => ['product:create']]),
        new Put(denormalizationContext: ['groups' => ['product:update']]),
        new Patch(denormalizationContext: ['groups' => ['product:update']]),
        new Delete(security: "is_granted('ROLE_ADMIN')"),
    ],
)]
class Product { /* ... */ }
```

### Per-operation rules

- **An operation is a closed contract.** Groups, security, validation, filters are set on the operation, not globally.
- **Never reuse the same group between read and write.** Separate `product:read` and `product:create` / `product:update`.
- **`GetCollection` is not `Get`** in terms of groups: the list should expose fewer fields than the detail view.
- **`Put` replaces, `Patch` modifies partially.** PATCH requires `Content-Type: application/merge-patch+json`.
- **Delegate to IRIs for relations** — no embedded objects by default (unless explicitly required).

### `shortName`, `uriTemplate`, prefix

- `shortName: 'Product'` keeps the URL stable even if you rename the class.
- `uriTemplate: '/v1/products/{id}'` enables URI-based versioning.
- Global prefix via route configuration:

```yaml
# config/routes/api_platform.yaml
api_platform:
    resource: .
    type: api_platform
    prefix: /api
```

---

## 4. The IRI-only rule for relations

**Never** put a scalar identifier (`int $customerId`, `string $productSku`) in an API contract. Always a **Resource** that API Platform resolves from its IRI.

| ❌ Forbidden | ✅ Correct |
|---|---|
| `public int $customerId` | `public Customer $customer` |
| `public string $productSku` | `public Product $product` |
| `customer_id: 42` (payload) | `"customer": "/api/customers/01J9..."` |

**Why it matters**:

- **Uniform security**: resolving the IRI triggers the voter on the target resource. With a scalar ID you would have to re-implement the check in the Processor.
- **Multi-tenant isolation**: if the user can't see `/api/customers/01J9...`, the IRI fails with 404/403; a scalar ID would not know.
- **No reimplementation**: no manual `findOneBy(['id' => $customerId])` for every endpoint.
- **Clean OpenAPI**: the doc shows a reference to a resource, not a magic identifier.
- **Client consistency**: API consumers speak IRIs everywhere (PATCH, POST, embed, expand).

If the target Resource does not exist yet — **create it**. No exception, no bypass.

---

## 5. `itemUriTemplate` — consistent IRIs on nested routes

When you declare a nested collection route (`/customers/{customerId}/orders`), the IRI emitted for individual items defaults to the admin route `/orders/{id}`. To force the nested route on items too:

```php
new GetCollection(
    uriTemplate: '/customers/{customerId}/orders',
    itemUriTemplate: '/customers/{customerId}/orders/{id}',
    uriVariables: [
        'customerId' => new Link(fromClass: Customer::class, toProperty: 'customer'),
    ],
),
```

The IRIs in the response now point to `/customers/.../orders/{id}` instead of the admin path.

---

## 6. Subresources (API Platform 4.x)

Express a hierarchy (orders of a customer, items of an order) by stacking **multiple `#[ApiResource]`** attributes on the same class with `uriTemplate` + `uriVariables` referencing the parent through `Link`.

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\Link;

#[ApiResource]                                              // /api/orders/{id}
#[ApiResource(
    uriTemplate: '/customers/{customerId}/orders',
    uriVariables: [
        'customerId' => new Link(fromClass: Customer::class, toProperty: 'customer'),
    ],
    operations: [new GetCollection()],
)]
#[ApiResource(
    uriTemplate: '/customers/{customerId}/orders/{id}',
    uriVariables: [
        'customerId' => new Link(fromClass: Customer::class, toProperty: 'customer'),
        'id'         => new Link(fromClass: Order::class),
    ],
    operations: [new Get()],
)]
class Order { /* ... */ }
```

Generated URIs:

```
GET  /api/orders/{id}
GET  /api/customers/{customerId}/orders
GET  /api/customers/{customerId}/orders/{id}
```

### Subresource rules

- `fromProperty` when the relation is owned by the source class (`Customer::orders`).
- `toProperty` when the relation is owned by the target class (`Order::customer`).
- Doctrine queries are **automatically scoped** by the parent — no extension needed.
- **Per-link security**: enable `enable_link_security: true` to apply a voter at the `Link` level:

```php
new Link(
    fromClass: Customer::class,
    toProperty: 'customer',
    security: "is_granted('CUSTOMER_VIEW', customer)",
)
```

Reference: <https://api-platform.com/docs/core/subresources/>.

---

## 7. Content negotiation (4.3)

### Native formats

| Name | MIME | Usage |
|---|---|---|
| `jsonld` | `application/ld+json` | **Default** 4.x format (Hydra) |
| `jsonhal` | `application/hal+json` | Minimal HATEOAS |
| `jsonapi` | `application/vnd.api+json` | JSON:API standard |
| `json` | `application/json` | Plain JSON (must be explicitly enabled in 4.x) |
| `xml` | `application/xml`, `text/xml` | Generic XML |
| `yaml` | `application/x-yaml` | Export |
| `csv` | `text/csv` | Tabular export |
| `html` | `text/html` | Swagger / Scalar UI |

### Reference configuration

```yaml
api_platform:
    formats:
        jsonld:    ['application/ld+json']
        json:      ['application/json']                       # opt-in
        jsonhal:   ['application/hal+json']
        jsonapi:   ['application/vnd.api+json']
        multipart: ['multipart/form-data']
        csv:       ['text/csv']
        html:      ['text/html']

    docs_formats:
        jsonld:        ['application/ld+json']
        jsonopenapi:   ['application/vnd.openapi+json']
        html:          ['text/html']

    error_formats:
        jsonproblem: ['application/problem+json']
        jsonld:      ['application/ld+json']
        jsonapi:     ['application/vnd.api+json']

    patch_formats:
        json:    ['application/merge-patch+json']
        jsonapi: ['application/vnd.api+json']
```

### Per-operation overrides

```php
new Patch(inputFormats: ['json' => ['application/merge-patch+json']])
new GetCollection(outputFormats: ['csv' => ['text/csv']])
```

### Linked Data Platform headers (4.3)

API Platform 4.3 automatically adds:

- `Allow: GET, POST, …` — methods allowed on the resource.
- `Accept-Post: application/ld+json, application/json` — formats accepted on POST.

### Resolution order

1. Format requested by the client (`Accept` header, or URL extension `.json` / `.ld+json`).
2. First format declared in `formats:` (fallback).
3. Unsupported format → **HTTP 415 Unsupported Media Type**.

---

## 8. Custom Symfony controllers — legacy, avoid

The official 4.x doc states: *« Using custom Symfony controllers with API Platform is discouraged. GraphQL is not supported. For most use cases, better extension points, working both with REST and GraphQL, are available. »* — <https://api-platform.com/docs/symfony/controllers/>.

**Prefer a State Provider or State Processor** for any custom logic. This section exists to help reviewers recognize the legacy pattern and migrate away.

### When a controller is still acceptable

- Behavior tightly coupled to Symfony (legacy multipart, HTML preview render, redirects).
- No GraphQL support needed.
- Existing codebase not yet migrated — read before you rewrite.

Otherwise → **a processor does it better**.

### Required flag in 4.x

```yaml
# config/packages/api_platform.yaml
api_platform:
    use_symfony_listeners: true   # mandatory when you keep Symfony controllers / listeners
```

Without this flag, Symfony listeners (ParamConverter, Security, etc.) are not wired into the API Platform pipeline.

### Invokable controller skeleton

```php
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpKernel\Attribute\AsController;

#[AsController]
final class PublishBookAction extends AbstractController
{
    public function __construct(private BookPublishingHandler $handler) {}

    public function __invoke(Book $book): Book
    {
        $this->handler->publish($book);
        return $book;
    }
}
```

```php
#[ApiResource(operations: [
    new Post(
        name: 'publish',
        uriTemplate: '/books/{id}/publish',
        controller: PublishBookAction::class,
    ),
])]
class Book { /* ... */ }
```

### Pipeline-skip flags

- `read: false` — skip auto-loading the entity.
- `deserialize: false` — skip body deserialization.
- `validate: false` — skip Symfony validation.
- `write: false` — skip auto-persistence (you handle it).

### `PlaceholderAction` — zero logic

```php
use ApiPlatform\Action\PlaceholderAction;

new Post(controller: PlaceholderAction::class)
```

Useful when the operation only exists to mint the URL and all the work lives in a voter / event / normalizer.

### Migration recipe — Controller → Processor

Before:

```php
#[AsController]
final class PublishBookAction
{
    public function __invoke(Book $book): Book
    {
        $this->handler->publish($book);
        return $book;
    }
}
```

After:

```php
final readonly class PublishBookProcessor implements ProcessorInterface
{
    public function __construct(
        private BookPublishingHandler $handler,
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private ProcessorInterface $persist,
    ) {}

    public function process(mixed $data, Operation $op, array $uriVars = [], array $ctx = []): Book
    {
        $this->handler->publish($data);
        return $this->persist->process($data, $op, $uriVars, $ctx);
    }
}

#[ApiResource(operations: [
    new Post(
        name: 'publish',
        uriTemplate: '/books/{id}/publish',
        processor: PublishBookProcessor::class,
    ),
])]
class Book { /* ... */ }
```

Advantages: REST + GraphQL compatible, more testable (explicit interface), no HTTP-framework coupling.

---

## 9. Symfony kernel events — deprioritized

Kernel events still work in 4.x but are **explicitly deprioritized**: *« We recommend using state providers and processors to extend API Platform internals. »* — <https://api-platform.com/docs/core/events/>.

### When listeners are still justified

- Modifying the final `Response` object (dynamic cache headers, Sunset headers).
- Cross-cutting logging (audit log, metrics).
- Logic that is strictly HTTP-transport (CORS preflight, redirection).

For anything related to data, security, or business logic, **switch to a Provider or Processor** — they work for REST and GraphQL, expose an explicit interface, and decorate cleanly via `#[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]`.

### `extraProperties` flags to skip pipeline stages

```php
new Get(extraProperties: [
    '_api_receive' => false,   // skip read + deserialize + validate
    '_api_respond' => false,   // skip serialize + respond
    '_api_persist' => false,   // skip write
])
```

### Event priorities (REST only — for reference)

| Hook | Event | Priority |
|---|---|---|
| `PRE_READ` | `kernel.request` | 5 |
| `POST_READ` | `kernel.request` | 3 |
| `PRE_DESERIALIZE` | `kernel.request` | 3 |
| `POST_DESERIALIZE` | `kernel.request` | 1 |
| `PRE_VALIDATE` | `kernel.view` | 65 |
| `POST_VALIDATE` | `kernel.view` | 63 |
| `PRE_WRITE` | `kernel.view` | 33 |
| `POST_WRITE` | `kernel.view` | 31 |
| `PRE_SERIALIZE` | `kernel.view` | 17 |
| `POST_SERIALIZE` | `kernel.view` | 15 |
| `PRE_RESPOND` | `kernel.view` | 9 |
| `POST_RESPOND` | `kernel.response` | 0 |

GraphQL does not fire these — yet another reason to prefer Providers / Processors.

---

## 10. Validation commands

```bash
# Confirm operations are wired up
php bin/console debug:router | grep api

# Inspect the generated OpenAPI spec
php bin/console api:openapi:export --yaml
php bin/console api:openapi:export --filter-tags=public
php bin/console api:openapi:export --api-gateway     # AWS API Gateway compatibility

# Generators
php bin/console make:state-provider
php bin/console make:state-processor

# Functional tests
./vendor/bin/phpunit --filter=Api
./vendor/bin/paratest -p8
```

---

## 11. Anti-patterns specific to resources

- ❌ Exposing every column of the entity without explicit groups.
- ❌ Reusing the same group for reads and writes.
- ❌ A Resource that is also a Doctrine Entity for a complex case where contract and storage diverge — split them.
- ❌ Scalar identifiers in payloads (`customerId: 42`) instead of IRIs.
- ❌ Forgetting `MaxDepth` on circular relations.
- ❌ Implicit operations — the resource attribute alone, without `operations: []`. Declare every operation.
- ❌ Custom Symfony controllers when a Processor suffices (cf. §8).
- ❌ `use_symfony_listeners: true` enabled unnecessarily — it disables a 4.x perf optimization.

---

## 12. Related skills

- `gerard:api-platform-dto-resources` — when the contract diverges from the entity, use DTOs (and the 4.3 Object Mapper).
- `gerard:api-platform-state-providers` — read pipeline customization.
- `gerard:api-platform-state-processors` — write pipeline customization.
- `gerard:api-platform-serialization` — groups, `#[Context]`, BackedEnum, MaxDepth.
- `gerard:api-platform-security` — operation / property security, voters, JWT, CORS.
- `gerard:api-platform-filters` — modern 4.3 `parameters` + `QueryParameter` pattern.
- `gerard:api-platform-tests` — `ApiTestCase`, DAMA, Foundry, schema assertions.
- `gerard:api-platform-versioning` — URI / DTO / header versioning.
- `gerard:api-platform-upgrade` — legacy 3.x / 4.0-4.2 patterns and how to migrate.
