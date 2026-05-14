# API Platform — Upgrade Guide (reference)

> **This is the only file in the plugin allowed to document legacy patterns** (`#[ApiFilter]`, `AbstractFilter`, `openapiContext`, `hydra:member`, `ApiPlatform\Core\`, `SerializerAwareProviderInterface`, `SerializableProvider`, `event_listeners_backward_compatibility_layer`, `keep_legacy_inflector`, `SearchFilter`/`OrderFilter`/`DateFilter`/`RangeFilter`/`NumericFilter`/`BooleanFilter` legacy classes). The anti-regression lint allows these mentions here.

## 1. 3.x → 4.0

### Breaking changes

- Namespace: `ApiPlatform\Core\…` → `ApiPlatform\…` (notably `ApiPlatform\Metadata\…`).
- Package split: `api-platform/core` (legacy monolith) → `api-platform/symfony` + `api-platform/doctrine-orm` + `api-platform/doctrine-mongodb-odm`.
- DataProviders / DataPersisters → **State Providers / State Processors** (new namespaces under `ApiPlatform\State\…`).
- `hydra_prefix: false` is the new default (legacy clients must opt back in with `hydra_prefix: true`).
- `standard_put: true` is the new default — PUT now replaces the resource entirely.
- `rfc_7807_compliant_errors: true` is the new default — error payloads follow RFC 7807.
- Doctrine Inflector → `symfony/string` (custom `PathSegmentNameGenerator` required if you relied on specific singular/plural behavior).
- `ApiPlatform\Symfony\Validator\Exception\ValidationException` → `ApiPlatform\Validator\Exception\ValidationException` (moved).

### Migration tools

- [`lyrixx/rector-apip-openapi`](https://github.com/lyrixx/rector-apip-openapi) — automatically converts `openapiContext` → `openapi: new Model\Operation()`.

### Config flags that must be **absent** in 4.x

```yaml
# ❌ DELETE
api_platform:
    event_listeners_backward_compatibility_layer: false
    keep_legacy_inflector:                         false
    validator:
        legacy_validation_exception: true
```

---

## 2. 4.0 → 4.2

### Breaking changes

- `#[ApiFilter]` + `AbstractFilter` **deprecated** → `parameters: [QueryParameter / HeaderParameter]` with directly instantiated filters (`new ExactFilter()`, etc.).
- Filters are no longer registered as services in the modern pattern.
- New filter classes : `ExactFilter`, `PartialSearchFilter`, `IriFilter`, `ComparisonFilter`, `SortFilter`, `FreeTextQueryFilter`, `OrFilter` — replace `SearchFilter`, `OrderFilter`, `DateFilter`, `NumericFilter`, `RangeFilter`, `BooleanFilter` (still functional but legacy).

### Legacy → modern filter mapping

| Pattern legacy | Replacement |
|---|---|
| `#[ApiFilter(SearchFilter::class, properties: ['name' => 'partial'])]` | `parameters: ['name' => new QueryParameter(filter: new PartialSearchFilter(), property: 'name')]` |
| `#[ApiFilter(SearchFilter::class, properties: ['sku' => 'exact'])]` | `parameters: ['sku' => new QueryParameter(filter: new ExactFilter(), property: 'sku')]` |
| `#[ApiFilter(SearchFilter::class, properties: ['category' => 'exact'])]` (FK) | `parameters: ['category' => new QueryParameter(filter: new IriFilter(), property: 'category')]` |
| `#[ApiFilter(OrderFilter::class, properties: ['name', 'createdAt'])]` | `parameters: ['orderName' => new QueryParameter(filter: new SortFilter(), property: 'name'), 'orderDate' => new QueryParameter(filter: new SortFilter(), property: 'createdAt')]` |
| `#[ApiFilter(DateFilter::class, properties: ['createdAt'])]` | `parameters: ['createdAt' => new QueryParameter(filter: new ComparisonFilter(new ExactFilter()), property: 'createdAt')]` |
| `#[ApiFilter(RangeFilter::class, properties: ['price'])]` | `parameters: ['price' => new QueryParameter(filter: new ComparisonFilter(new ExactFilter()), property: 'price')]` |
| `#[ApiFilter(NumericFilter::class, properties: ['stock'])]` | same as above (ComparisonFilter or ExactFilter depending on operators needed) |
| `#[ApiFilter(BooleanFilter::class, properties: ['isActive'])]` | `parameters: ['isActive' => new QueryParameter(filter: new ExactFilter(), property: 'isActive')]` (ExactFilter accepts true/false/1/0) |
| `#[ApiFilter(ExistsFilter::class, properties: ['deletedAt'])]` | `parameters: ['exists[deletedAt]' => new QueryParameter(filter: new ExistsFilter())]` |
| `extends AbstractFilter` | `implements FilterInterface` + `BackwardCompatibleFilterDescriptionTrait` + `JsonSchemaFilterInterface` + `OpenApiParameterFilterInterface` (with `OpenApiFilterTrait`) |

For custom filters, run `make:filter orm Foo` / `make:filter odm Foo` to scaffold the modern shape.

---

## 3. 4.2 → 4.3

### Confirmed breaking changes

1. **Filters — `property` is now mandatory** on `ExactFilter`, `IriFilter`, `PartialSearchFilter`, `UuidFilter`:

   ```php
   // ❌ Before (silently accepted in 4.2)
   #[ApiFilter(ExactFilter::class)]

   // ✅ 4.3 (otherwise InvalidArgumentException)
   #[ApiFilter(ExactFilter::class, property: 'name')]
   // or via QueryParameter with explicit property: or the :property placeholder
   ```

2. **`readonly` Doctrine entities lose auto-exposed PUT/PATCH.** Write operations are no longer auto-exposed on classes marked via `$classMetadata->markReadOnly()`. Declare write operations explicitly if needed.

3. **JSON-LD `@type` with `output:` + `itemUriTemplate`** now uses the **resource class** name (not the DTO). Update clients that match on `@type`.

### Behavioral changes

- **`isGranted` evaluated before the state provider** when the expression does not reference `object` — perf gain, but may change the timing of side effects.
- **Hydra `@id` uses `#ShortName`** instead of `schema.org` URIs (avoids semantic collisions). The schema.org types are still exposed via `rdfs:subClassOf`.
- **LDP headers `Allow` + `Accept-Post`** added automatically (informational).

### 4.3 novelties

- `api-platform/mcp` + `symfony/mcp-bundle` — Model Context Protocol (cf. `gerard:api-platform-mcp`).
- **Symfony Object Mapper** integration — `composer require symfony/object-mapper` + `#[Map]` (cf. `gerard:api-platform-dto-resources`).
- **Scalar API Reference** — `/api/docs?ui=scalar`, `enable_scalar: false` to disable.
- `#[AsResourceMutator]`, `#[AsOperationMutator]` (cf. `gerard:api-platform-mutators`).
- `UuidFilter` (Doctrine ORM/ODM).
- `IriFilter` / `UuidFilter` support **nested relations** (dot notation).
- `ComparisonFilter` operator `ne` (not equal).
- `caseSensitive` option on `PartialSearchFilter`.
- ODM `SortFilter` + nested parameters.
- Default global parameters (`defaults.parameters`).
- Native parameter validation for UUID/ULID.
- `castToNativeType` / `castToArray` / `castFn` on `QueryParameter`.
- `IriConverterParameterProvider`, `ReadLinkParameterProvider`.
- `PropertyFilter` (sparse fieldsets) — native.
- `SkipAutoconfigure` attribute to bypass autoconfigure.
- `defaults.normalization_context.gen_id` config flag.
- Elasticsearch / OpenSearch SSL options.
- Symfony makers namespace configuration.

### Deprecations 4.2 → removed in v5

- `SerializerAwareProviderInterface`
- `SerializableProvider`

---

## 4. Preparing v5

### Eliminate the following now to make the v5 cut-over trivial

| Legacy pattern | Replacement |
|---|---|
| `#[ApiFilter(...)]` | `parameters: [... => new QueryParameter(filter: new ExactFilter())]` |
| `extends AbstractFilter` | `implements FilterInterface` + `BackwardCompatibleFilterDescriptionTrait` |
| `openapiContext` | `openapi: new Model\Operation(...)` |
| `event_listeners_backward_compatibility_layer` | (remove the line) |
| `keep_legacy_inflector` | (remove the line) |
| `ApiPlatform\Symfony\Validator\Exception\ValidationException` | `ApiPlatform\Validator\Exception\ValidationException` |
| Custom invokable controllers | Processors / Providers |
| `SearchFilter::partial` | `PartialSearchFilter` |
| `SearchFilter::exact` | `ExactFilter` |
| `SearchFilter` on a FK | `IriFilter` |
| `DateFilter`, `RangeFilter`, `NumericFilter` ranges | `ComparisonFilter(new ExactFilter())` |
| `OrderFilter` | `SortFilter` |
| `BooleanFilter` | `ExactFilter` |
| `SerializerAwareProviderInterface` | — (remove implementation) |
| `SerializableProvider` | — (remove implementation) |
| `NelmioApiDocBundle` (legacy 2.9/3.0) | Native OpenAPI + Scalar (cf. `gerard:api-platform-openapi`) |
| `ApiPlatform\Core\…` namespace | `ApiPlatform\…` |
| `api-platform/core` (monolithic) | `api-platform/symfony` + `api-platform/doctrine-orm` |

### Tooling

- **`composer outdated api-platform/*`** — surface upgradable packages.
- **`rector`** + `lyrixx/rector-apip-openapi` — automatable for `openapiContext`.
- **PHPStan custom rule** — fail CI on new `#[ApiFilter]` usage.
- **Deptrac** — isolate the migration progressively (one module at a time).

---

## 5. Audit and rollout checklist

### Audit

```bash
# Locate legacy patterns
rg "ApiPlatform\\\\Core\\\\" src/
rg "#\[ApiFilter" src/
rg "openapiContext" src/
rg "hydra:(member|totalItems|view|next)" tests/
rg "extends AbstractFilter" src/
rg "SerializerAwareProviderInterface|SerializableProvider" src/

# Version inventory
composer show api-platform/symfony api-platform/doctrine-orm api-platform/core
composer outdated api-platform/*

# Security
composer audit
```

### Rollout

1. Pin `api-platform/symfony` and `api-platform/doctrine-orm` to `^4.3`.
2. Run Rector (`lyrixx/rector-apip-openapi`) to migrate `openapiContext`.
3. Replace each `#[ApiFilter]` with the corresponding `parameters: [QueryParameter]` block (see §2 table).
4. Update tests: replace `hydra:member` / `hydra:totalItems` etc. with the unprefixed keys (default page size 30 in 4.x).
5. Remove legacy config flags (§1).
6. Delete legacy interfaces (`SerializerAwareProviderInterface`, `SerializableProvider`).
7. For each `readonly` entity that still needs PUT/PATCH, declare write operations explicitly.
8. Re-run the full test suite (DAMA + Foundry + ParaTest).
9. Enable v5 guard rails: PHPStan rule, Deptrac layer.

---

## 6. Test re-baselining

Before:

```php
$this->assertJsonContains([
    '@context'          => '/api/contexts/Product',
    '@type'             => 'hydra:Collection',
    'hydra:totalItems'  => 30,
]);
$this->assertCount(20, $response->toArray()['hydra:member']);
```

After (4.x):

```php
$this->assertJsonContains([
    '@context'   => '/api/contexts/Product',
    '@type'      => 'Collection',
    'totalItems' => 30,
]);
$this->assertCount(30, $response->toArray()['member']);  // default 30 in 4.x, not 20
```

---

## 7. Related skills

- `gerard:api-platform-resources` — modern operation declaration.
- `gerard:api-platform-filters` — modern `parameters + QueryParameter` pattern.
- `gerard:api-platform-tests` — JSON-LD shape in 4.x.
- `gerard:api-platform-versioning` — `openapi: new Model\Operation` deprecation flag.
- `gerard:api-platform-openapi` — Scalar UI, OpenAPI factory decoration.
- `gerard:api-platform-state-providers` / `gerard:api-platform-state-processors` — the 4.x successors to DataProviders / DataPersisters.
