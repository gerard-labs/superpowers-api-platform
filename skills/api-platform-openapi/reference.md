# API Platform 4.3 — OpenAPI / Hydra / Scalar (reference)

## 1. Default format — JSON-LD + Hydra + RDF

API Platform natively serves responses as JSON-LD (`application/ld+json`) with Hydra controls and, optionally, RDF vocabulary.

- **JSON-LD** describes entities, attributes, relations machine-readably. The `@context` clarifies field meaning.
- **Hydra** adds hypermedia controls (`Collection`, `totalItems`, `next`, `operation`) — HATEOAS for free. In 4.x, no `hydra:` prefix by default.
- **RDF** (optional) annotates fields with a standard vocabulary (schema.org, foaf, …) for semantic interoperability.

### Benefits

- Automatic operation discovery for Hydra-aware clients.
- Generated SDKs straight from OpenAPI.
- No ad-hoc adapters between partner systems.

### Test assertion

```php
$this->assertResponseHeaderSame(
    'content-type',
    'application/ld+json; charset=utf-8'
);
```

### Re-enabling legacy `hydra:` prefix (compat 3.x clients)

```yaml
api_platform:
    serializer:
        hydra_prefix: true
```

(Only if you have downstream consumers that still parse `hydra:member` etc.)

---

## 2. UIs — Swagger / ReDoc / Scalar (4.3)

- **OpenAPI spec** auto-served at `/api/docs` (negotiated by `Accept`).
- **Swagger UI** by default at `/api/docs` (HTML).
- **ReDoc** available (`enable_re_doc: true`).
- **Scalar UI (NEW 4.3)**: `/api/docs?ui=scalar`. Disable via `enable_scalar: false`.

### Exporting

```bash
# YAML, OpenAPI 3.0
php bin/console api:openapi:export --yaml --spec-version=3.0.0

# Filter by tag
php bin/console api:openapi:export --filter-tags=customer

# AWS API Gateway compatibility
php bin/console api:openapi:export --api-gateway        # or ?api_gateway=true
```

---

## 3. `openapi` attribute (4.x — recommended)

> ⚠️ `openapiContext` (3.x) is deprecated. The replacement is `openapi: new \ApiPlatform\OpenApi\Model\Operation(...)`. A Rector script (`lyrixx/rector-apip-openapi`) automates the migration.

```php
use ApiPlatform\Metadata\Post;
use ApiPlatform\OpenApi\Model;

#[Post(
    openapi: new Model\Operation(
        summary:     'Create a book',
        description: 'Creates a book and returns it.',
        tags:        ['Books', 'Public'],
        deprecated:  false,
        parameters: [
            new Model\Parameter(name: 'fields', in: 'query', description: 'Sparse fieldsets'),
        ],
        requestBody: new Model\RequestBody(
            content: new \ArrayObject([
                'application/ld+json' => [
                    'schema'  => ['type' => 'object', 'required' => ['title']],
                    'example' => ['title' => 'Hello'],
                ],
            ]),
        ),
        responses: [
            201 => new Model\Response(description: 'Created'),
            422 => new Model\Response(description: 'Validation error'),
        ],
    ),
)]
class Book { /* ... */ }
```

### Classes in `ApiPlatform\OpenApi\Model`

- `Operation`
- `Parameter`
- `RequestBody`
- `Response`
- `Info` (title, version, contact, license)
- `Server`
- `Contact`
- `License`

---

## 4. Global OpenAPI customization (factory decorator)

```php
use ApiPlatform\OpenApi\Factory\OpenApiFactoryInterface;
use ApiPlatform\OpenApi\Model;
use ApiPlatform\OpenApi\OpenApi;
use Symfony\Component\DependencyInjection\Attribute\AsDecorator;
use Symfony\Component\DependencyInjection\Attribute\AutowireDecorated;

#[AsDecorator(decorates: 'api_platform.openapi.factory')]
final class CustomOpenApiFactory implements OpenApiFactoryInterface
{
    public function __construct(
        #[AutowireDecorated]
        private OpenApiFactoryInterface $decorated,
    ) {}

    public function __invoke(array $context = []): OpenApi
    {
        $openApi = $this->decorated->__invoke($context);

        $openApi = $openApi->withInfo(new Model\Info(
            title:       'Acme API',
            version:     '2.0.0',
            description: 'Acme corporate API',
            contact:     new Model\Contact(name: 'API team', email: '[email protected]'),
            license:     new Model\License(name: 'Proprietary'),
        ));

        $openApi = $openApi->withExtensionProperty('x-logo', ['url' => 'https://acme.test/logo.png']);

        return $openApi;
    }
}
```

---

## 5. Custom filter descriptions

### Modern 4.3 path

For filters implementing `JsonSchemaFilterInterface::getSchema()` + `OpenApiParameterFilterInterface` (with the `OpenApiFilterTrait`), the OpenAPI doc is generated automatically. Nothing to do (cf. `gerard:api-platform-filters`).

### Legacy `getDescription()` path (only for migration)

For filters still implementing `getDescription()` (path that has to disappear in v5), the structure is:

```php
public function getDescription(string $resourceClass): array
{
    return [
        'month' => [
            'type'        => 'integer',
            'required'    => false,
            'description' => 'Month of the year (1-12)',
            'openapi'     => ['example' => 6, 'minimum' => 1, 'maximum' => 12],
        ],
    ];
}
```

Move to the modern path as soon as possible (cf. `gerard:api-platform-upgrade`).

---

## 6. Schema customization

### Custom schema name

```php
new Post(denormalizationContext: [
    'groups'                  => ['user:write'],
    'openapi_definition_name' => 'UserCreate',   // schema name in the spec
])
```

### Hide an operation from the doc

```php
new GetCollection(openapi: false)
```

### Tags

```php
new Get(openapi: new Model\Operation(tags: ['Users', 'Internal']))
```

### Mark as deprecated (cf. `gerard:api-platform-versioning`)

```php
new Get(
    deprecationReason: 'Use /v2/products/{id} instead.',
    sunset:            '2026-01-01',
    openapi:           new Model\Operation(deprecated: true),
)
```

Emits a `Deprecation: true` header and a `Sunset: ...` (RFC 8594).

---

## 7. Vendor extensions (`x-*`)

```php
$openApi->withExtensionProperty('x-rate-limit-headers', true);
```

Per-operation:

```php
new Get(openapi: new Model\Operation(extensionProperties: [
    'x-internal' => true,
]))
```

---

## 8. Security in OpenAPI

```php
new Get(openapi: new Model\Operation(
    security: [['bearerAuth' => []]],
))
```

Global declaration:

```yaml
api_platform:
    swagger:
        api_keys:
            JWT:
                name: Authorization
                type: header
```

This makes the "Authorize" button work in Swagger UI; the user enters `Bearer <token>`. Cf. `gerard:api-platform-security` for the full JWT integration.

---

## 9. Architecture Decision Records (ADR)

Significant decisions (database choice, versioning strategy, cache strategy, error structure) should be **versioned** in `docs/adr/`.

Standard ADR structure:

```markdown
# ADR-0007 : URI versioning for breaking changes

## Context
The API exposes v1 to 12 partners; a breaking change is required for the catalog model rework planned in Q3-2026.

## Decision
We adopt URI versioning (`/v1/`, `/v2/`) rather than header-based versioning.

## Consequences
+ Readable for consumers.
+ No content-negotiation needed.
- We maintain two sets of routes during the transition.
```

**Rule**: reference the ADR in commit messages and code reviews. A superseded ADR is marked `Status: superseded by ADR-XXXX`, never deleted (decisional history).

---

## 10. Configuration recap

```yaml
api_platform:
    title:       'My API'
    description: 'My API description'
    version:     '1.0.0'

    enable_swagger:    true   # OpenAPI spec exposed
    enable_swagger_ui: true   # Swagger UI
    enable_re_doc:     true   # ReDoc UI
    enable_scalar:     true   # Scalar UI (4.3)
    enable_docs:       true   # /api/docs
    enable_entrypoint: true   # /api
    enable_profiler:   true   # debug panel

    swagger:
        api_keys:
            JWT:
                name: Authorization
                type: header
```

Cf. `docs/symfony/api-platform-config-4.3.md` for the full configuration reference.

---

## 11. Related skills

- `gerard:api-platform-resources` — operation declaration where the `openapi` attribute lands.
- `gerard:api-platform-versioning` — deprecation flags surfaced in OpenAPI.
- `gerard:api-platform-filters` — `JsonSchemaFilterInterface` / `OpenApiParameterFilterInterface`.
- `gerard:api-platform-security` — security scheme alignment.
- `gerard:api-platform-mcp` — exposes operations as MCP tools (OpenAPI-aware).
- `gerard:api-platform-upgrade` — migrating from `openapiContext`.
