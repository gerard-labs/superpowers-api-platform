# API Platform 4.3 — Errors (reference)

## 1. Global configuration

```yaml
api_platform:
    defaults:
        extra_properties:
            rfc_7807_compliant_errors: true    # default in 4.x
    exception_to_status:
        Symfony\Component\Serializer\Exception\ExceptionInterface: 400
        ApiPlatform\Exception\InvalidArgumentException:            400
        Doctrine\ORM\OptimisticLockException:                       409
        App\Exception\ProductNotFoundException:                     404
        App\Exception\InsufficientStockException:                   409
```

`rfc_7807_compliant_errors: true` makes the API return `application/problem+json` responses:

```json
{
  "type":     "/errors/v1/stock-unavailable",
  "title":    "Stock unavailable",
  "status":   409,
  "detail":   "Only 2 units of SKU ABC-123 remain.",
  "instance": "/api/orders/01J9..."
}
```

---

## 2. Mapping per resource or per operation

```php
#[ApiResource(
    exceptionToStatus: [ProductNotFoundException::class => 404],
    operations: [
        new Get(exceptionToStatus: [ProductWasRemovedException::class => 410]),
    ],
)]
class Book { /* ... */ }
```

Resource-level overrides the config; operation-level overrides resource-level.

---

## 3. Documenting an exception in OpenAPI (4.3)

```php
new GetCollection(errors: [MyDomainException::class])
```

The exception is automatically surfaced in the OpenAPI schema as a documented failure response. Pair with `#[ErrorResource]` (next section) to get a fully typed error contract.

---

## 4. `#[ErrorResource]` — exceptions as documented resources

```php
use ApiPlatform\Metadata\ErrorResource;
use ApiPlatform\Metadata\Exception\ProblemExceptionInterface;

#[ErrorResource]
class StockUnavailableError extends \Exception implements ProblemExceptionInterface
{
    public function getType(): string     { return '/errors/v1/stock-unavailable'; }
    public function getTitle(): ?string   { return 'Stock unavailable'; }
    public function getStatus(): ?int     { return 409; }
    public function getDetail(): ?string  { return $this->getMessage(); }
    public function getInstance(): ?string { return null; }
}
```

The exception becomes a documented error resource. Sensitive fields (`trace`, `file`, `line`, `code`) are masked automatically via `ignored_attributes`.

Throw it from the domain:

```php
throw new StockUnavailableError(sprintf('Only %d units of SKU %s remain.', $stock, $sku));
```

API Platform produces:

```http
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{
  "type":   "/errors/v1/stock-unavailable",
  "title":  "Stock unavailable",
  "status": 409,
  "detail": "Only 2 units of SKU ABC-123 remain."
}
```

---

## 5. Custom Error Provider

When you need to mutate the error payload beyond what `#[ErrorResource]` offers, alias your provider on `api_platform.state.error_provider`:

```php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ApiResource\Error;
use ApiPlatform\State\ProviderInterface;
use Symfony\Component\DependencyInjection\Attribute\AsAlias;

#[AsAlias('api_platform.state.error_provider')]
final class ErrorProvider implements ProviderInterface
{
    public function provide(Operation $op, array $uriVars = [], array $ctx = []): object|array|null
    {
        $exception = $ctx['request']->attributes->get('exception');
        $status    = $op->getStatus() ?? 500;
        $error     = Error::createFromException($exception, $status);

        if ($status >= 500) {
            $error->setDetail('An unexpected error occurred.');   // no stack trace in prod
        }

        return $error;
    }
}
```

---

## 6. HTTP status resolution order (Symfony)

When an exception bubbles up, API Platform resolves the status in this order:

1. `exception_to_status` (config / per-resource / per-operation).
2. `Symfony\Component\HttpKernel\Exception\HttpExceptionInterface::getStatusCode()`.
3. `ApiPlatform\Metadata\Exception\ProblemExceptionInterface::getStatus()`.
4. `ApiPlatform\Metadata\Exception\HttpExceptionInterface`.
5. Defaults: `RequestExceptionInterface` → 400, `ValidationException` → 422.
6. `#[ErrorResource]` `getStatus()`.
7. Fallback: 500.

Knowing this order makes it easy to predict where to wire a given domain exception.

---

## 7. Validation Error Provider

```yaml
services:
    api_platform.validator.state.error_provider:
        tags:
            - { name: 'api_platform.state_provider', key: 'api_platform.validator.state.error_provider' }
```

This provider emits the 422 + `ConstraintViolationList` normalized per RFC 7807:

```json
{
  "type":   "https://tools.ietf.org/html/rfc4918#section-11.2",
  "title":  "An error occurred",
  "status": 422,
  "detail": "email: This value is not a valid email address.",
  "violations": [
    { "propertyPath": "email", "message": "This value is not a valid email address." }
  ]
}
```

---

## 8. Input validation — constraints, groups, custom validators

Validation is the upstream of the 422 path documented in §7. Place the constraints on the **DTO Input** when one exists (validation follows the API contract, not the persistence schema), otherwise on the entity.

### Constraints on the entity / DTO Input

```php
#[ORM\Entity]
#[UniqueEntity(fields: ['email'], message: 'This email is already registered.')]
class User
{
    #[Assert\NotBlank(message: 'Please enter your name.')]
    #[Assert\Length(min: 2, max: 100)]
    private string $name;

    #[Assert\NotBlank]
    #[Assert\Email]
    private string $email;
}
```

Rules:

- **Explicit, useful messages** — never just `"Invalid"`. The 422 body is what the front renders.
- **`UniqueEntity`** on the class for multi-field uniqueness.
- **Validate the DTO Input** when there is one — keeps the contract decoupled from persistence.
- **Never trust the client** — validation lives on the server even if the front does it too.

### Validation groups — context-aware rules

Different operations need different rules (registration requires `plainPassword`, profile update doesn't).

```php
#[Assert\NotBlank(groups: ['user:create'])]
private ?string $plainPassword = null;
```

Reference the group via `validationContext` on the operation:

```php
new Post(
    validationContext: ['groups' => ['Default', 'user:create']],
)
```

### Custom constraints

Extend `Constraint` + `ConstraintValidator`. Two guardrails:

- **Return early on empty value** — let `NotBlank` handle the presence check.
- **Throw `UnexpectedTypeException`** if the constraint instance is not the expected one.

### `ValidationException` namespace (4.x)

The class moved in 3.4:

- ❌ 3.x : `ApiPlatform\Symfony\Validator\Exception\ValidationException`
- ✅ 4.x : `ApiPlatform\Validator\Exception\ValidationException`

Update imports on migration. The legacy path still works through a BC layer **only** if `validator.legacy_validation_exception: true` is set — remove that flag on a clean 4.x project.

### Collect every deserialization error

By default, deserialization stops on the first error. To collect them all (useful for frontends that show every error at once):

```yaml
api_platform:
    defaults:
        collectDenormalizationErrors: true
```

Or per operation:

```php
new Post(collectDenormalizationErrors: true)
```

### Include payload fields in the error response (debug only)

```yaml
api_platform:
    validator:
        serialize_payload_fields: ['email', 'username']
```

⚠️ **Never include sensitive fields** — passwords, tokens, PII. The 422 body is visible to whoever triggered the error.

### Test the 422 on every write operation

The 422 is part of the contract. See `gerard:api-platform-tests` §7–§8 for the assertion patterns and the full failure-mode catalog.

---

## 9. Best practices

- **Hide 500 details in prod**: `setDetail('An unexpected error occurred.')` (or similar generic string). The full exception goes to the logs, not the response.
- **Always set a stable `type`** on `ProblemExceptionInterface` — clients pattern-match on this URI.
- **No business details in 401 / 403** — enumeration risk.
- **Version your error types** (`/errors/v1/...`) so you can evolve them without breaking clients.
- **Wire `errors: [...]`** on operations that can throw a domain exception — OpenAPI documents the failure response automatically.

---

## 10. Production-only safety net

```yaml
# config/packages/prod/api_platform.yaml
api_platform:
    show_webby: false              # hide the "API Platform" branding on errors
    enable_profiler: false
```

---

## 11. Test patterns

```php
public function test_insufficient_stock_returns_409_problem_json(): void
{
    $client = static::createClient();
    $client->request('POST', '/api/orders', [
        'json' => [/* … invalid stock … */],
    ]);

    $this->assertResponseStatusCodeSame(409);
    $this->assertResponseHeaderSame('content-type', 'application/problem+json; charset=utf-8');
    $this->assertJsonContains([
        'type'   => '/errors/v1/stock-unavailable',
        'title'  => 'Stock unavailable',
        'status' => 409,
    ]);
}
```

---

## 12. Related skills

- `gerard:api-platform-resources` — `exceptionToStatus`, `errors: [...]` on operations.
- `gerard:api-platform-security` — 401 / 403 semantics, no leakage.
- `gerard:api-platform-openapi` — surfacing errors in the spec.
- `gerard:api-platform-tests` — asserting Problem Detail payloads.
- `gerard:value-objects-and-dtos` — domain exceptions usually live in the same layer as the VOs they protect.
