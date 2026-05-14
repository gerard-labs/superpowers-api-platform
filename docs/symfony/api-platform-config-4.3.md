# API Platform 4.3 — Configuration reference

> Defaults for `config/packages/api_platform.yaml` on API Platform 4.3+.
> Source: <https://api-platform.com/docs/core/configuration/>.

## Recommended configuration for a new 4.3 project

```yaml
api_platform:
    title:       'My API'
    description: 'My API description'
    version:     '1.0.0'

    formats:
        jsonld: ['application/ld+json']
        json:   ['application/json']

    docs_formats:
        jsonld:      ['application/ld+json']
        jsonopenapi: ['application/vnd.openapi+json']
        html:        ['text/html']

    error_formats:
        jsonproblem: ['application/problem+json']
        jsonld:      ['application/ld+json']

    patch_formats:
        json: ['application/merge-patch+json']

    defaults:
        stateless: true
        cache_headers:
            etag:           true
            vary:           ['Content-Type', 'Authorization', 'Origin']
            max_age:        3600
            shared_max_age: 3600
        extra_properties:
            standard_put:              true
            rfc_7807_compliant_errors: true
        normalization_context:
            skip_null_values: true     # 4.x default

    # use_symfony_listeners: true     # ONLY if you keep custom controllers / listeners

    exception_to_status:
        Symfony\Component\Serializer\Exception\ExceptionInterface: 400
        Doctrine\ORM\OptimisticLockException:                       409

    eager_loading:
        enabled:       true
        force_eager:   false        # IMPORTANT — keep explicit
        fetch_partial: false
        max_joins:     30
```

## Notable defaults (4.3)

| Option | Default | Note |
|---|---|---|
| `title` | `'API title'` | Customize. |
| `description` | `'API description'` | Customize. |
| `version` | `'0.0.0'` | Version it. |
| `formats.jsonld` | `application/ld+json` | 4.x default format. |
| `formats.json` | (off) | Declare explicitly if needed. |
| `defaults.stateless` | `~` | Set `true` for JWT APIs. |
| `defaults.cache_headers.etag` | `true` | ETag auto. |
| `defaults.normalization_context.skip_null_values` | `true` | No `"x": null` in responses. |
| `defaults.extra_properties.standard_put` | `true` | PUT replaces the whole entity. |
| `defaults.extra_properties.rfc_7807_compliant_errors` | `true` | Problem-format errors. |
| `defaults.pagination_items_per_page` | `30` | (Not 20 — common mistake.) |
| `defaults.pagination_maximum_items_per_page` | `~` | Cap explicitly (50–100). |
| `defaults.pagination_partial` | `false` | Enable for huge collections. |
| `eager_loading.enabled` | `true` | |
| `eager_loading.force_eager` | `true` | ⚠️ Often counter-productive — set `false` and use targeted join fetches. |
| `eager_loading.fetch_partial` | `false` | |
| `eager_loading.max_joins` | `30` | Raise if many relations. |
| `enable_swagger` | `true` | OpenAPI spec exposed. |
| `enable_swagger_ui` | `true` | Swagger UI. |
| `enable_re_doc` | `true` | ReDoc UI. |
| `enable_entrypoint` | `true` | `/api`. |
| `enable_docs` | `true` | `/api/docs`. |
| `enable_profiler` | `true` | Debug panel. |
| `enable_scalar` | `true` (4.3) | Scalar UI (`/api/docs?ui=scalar`). |
| `mcp.enabled` | `false` | Enable for MCP integration. |
| `mercure.enabled` | `false` | Real-time. |
| `messenger.enabled` | `false` | Enable for native `messenger:` operation modes. |
| `graphql.enabled` | `false` | Enable for GraphQL. |
| `validator.query_parameter_validation` | `true` | Auto-validate query parameters. |
| `validator.serialize_payload_fields` | `[]` | Fields included in error responses (debug only — exclude PII). |
| `http_cache.invalidation.enabled` | `false` | Enable for Varnish-driven invalidation. |
| `serializer.hydra_prefix` | `false` | No `hydra:` prefix. |
| `collection.pagination.page_parameter_name` | `'page'` | |
| `collection.pagination.items_per_page_parameter_name` | `'itemsPerPage'` | |
| `collection.pagination.enabled_parameter_name` | `'pagination'` | |
| `collection.pagination.partial_parameter_name` | `'partial'` | |
| `collection.order_parameter_name` | `'order'` | |
| `collection.exists_parameter_name` | `'exists'` | |
| `resource_class_directories` | `['%kernel.project_dir%/src/Entity']` | Add `'%kernel.project_dir%/src/ApiResource'` if Resource-First. |
| `defaults.collectDenormalizationErrors` | `false` | Set `true` to collect all denormalization errors (vs stop at first). |
| `defaults.normalization_context.gen_id` | (4.3) | Control JSON-LD `@id` generation on nested objects. |

## Options that must be **absent** in 4.x (legacy 3.x)

```yaml
# ❌ DELETE
api_platform:
    event_listeners_backward_compatibility_layer: false
    keep_legacy_inflector:                         false
    validator:
        legacy_validation_exception: true
```

These were 3.x compatibility flags. Their presence in a 4.x project is a code smell — they no longer have an effect and may emit deprecation notices.

## Recommended overrides per environment

### Production

```yaml
# config/packages/prod/api_platform.yaml
api_platform:
    show_webby:    false      # remove the API Platform branding from errors
    enable_profiler: false
    metadata_backward_compatibility_layer: false
```

Add APCu metadata cache:

```yaml
framework:
    cache:
        pools:
            cache.api_platform:
                adapter: cache.adapter.apcu
```

### Test

Cf. `gerard:api-platform-tests` — lightweight password hashing (md5) and DAMA Doctrine test bundle wiring.

## Related skills

- `gerard:api-platform-resources`
- `gerard:api-platform-performance` — `eager_loading` trap, APCu metadata cache, FrankenPHP.
- `gerard:api-platform-tests` — test-environment configuration.
- `gerard:api-platform-upgrade` — migration from 3.x / 4.0-4.2 default flips.
