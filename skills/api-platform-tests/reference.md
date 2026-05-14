# API Platform 4.3 — Functional tests (reference)

## 1. Stack setup

```bash
composer require --dev symfony/test-pack symfony/http-client symfony/browser-kit
composer require --dev justinrainbow/json-schema           # for assertMatchesJsonSchema
composer require --dev dama/doctrine-test-bundle           # transaction rollback per test
composer require --dev zenstruck/foundry                   # factories + ResetDatabase
composer require --dev doctrine/doctrine-fixtures-bundle   # optional fixtures
composer require --dev brianium/paratest                   # parallel execution
```

### Hook DAMA into PHPUnit

```xml
<phpunit>
    <extensions>
        <extension class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension" />
    </extensions>
</phpunit>
```

### Lightweight password hashing in tests

```yaml
# config/packages/test/security.yaml
security:
    password_hashers:
        App\Entity\User:
            algorithm:        md5
            encode_as_base64: false
            iterations:       0
```

Speeds up the suite ×5 as soon as you create users.

---

## 2. Skeleton

```php
use ApiPlatform\Symfony\Bundle\Test\ApiTestCase;
use App\Tests\Factory\ProductFactory;
use Zenstruck\Foundry\Test\Factories;
use Zenstruck\Foundry\Test\ResetDatabase;

final class ProductTest extends ApiTestCase
{
    use Factories;
    use ResetDatabase;

    public function test_collection_returns_paginated_jsonld(): void
    {
        ProductFactory::createMany(30);

        $response = static::createClient()->request('GET', '/api/products');

        $this->assertResponseIsSuccessful();
        $this->assertResponseHeaderSame('content-type', 'application/ld+json; charset=utf-8');
        // 4.x : hydra_prefix: false by default → keys WITHOUT 'hydra:' prefix
        $this->assertJsonContains([
            '@context'   => '/api/contexts/Product',
            '@type'      => 'Collection',
            'totalItems' => 30,
        ]);
        $this->assertCount(30, $response->toArray()['member']);
    }

    public function test_find_iri_by_helper(): void
    {
        $product = ProductFactory::createOne(['sku' => 'ABC-123']);

        $iri = $this->findIriBy(\App\Entity\Product::class, ['sku' => 'ABC-123']);

        static::createClient()->request('GET', $iri);
        $this->assertResponseIsSuccessful();
    }
}
```

---

## 3. Reusable authenticated client (JWT pattern)

```php
use ApiPlatform\Symfony\Bundle\Test\ApiTestCase;
use ApiPlatform\Symfony\Bundle\Test\Client;

abstract class AbstractApiTest extends ApiTestCase
{
    private ?string $token = null;

    protected function createClientWithCredentials(?string $token = null): Client
    {
        $token ??= $this->getToken();
        return static::createClient([], [
            'headers' => ['authorization' => 'Bearer ' . $token],
        ]);
    }

    protected function getToken(array $credentials = []): string
    {
        if ($this->token) {
            return $this->token;
        }

        $response = static::createClient()->request('POST', '/auth', [
            'json' => $credentials ?: ['email' => '[email protected]', 'password' => '$3CR3T'],
        ]);
        $this->assertResponseIsSuccessful();

        return $this->token = $response->toArray()['token'];
    }
}
```

---

## 4. Multiple requests in a single test

The default `ApiTestCase` reboots the kernel between `request()` calls — losing the DAMA transaction. Disable it explicitly:

```php
$client = static::createClient();
$client->disableReboot();
$client->request('POST', '/api/orders', [/* ... */]);
$client->request('GET',  '/api/orders');   // without disableReboot: kernel reboots and rolls back
```

---

## 5. Schema assertions (lock down the contract)

```php
$this->assertMatchesResourceItemJsonSchema(\App\Entity\Product::class);
$this->assertMatchesResourceCollectionJsonSchema(\App\Entity\Product::class);
$this->assertMatchesJsonSchema(['type' => 'object', 'required' => ['id']]);
```

These verify the response shape against the OpenAPI schema generated for the resource. A drift between code and contract is detected immediately.

---

## 6. Multipart upload tests

```php
use Symfony\Component\HttpFoundation\File\UploadedFile;

public function test_can_upload_a_media_object(): void
{
    $file = new UploadedFile(__DIR__.'/../fixtures/image.jpg', 'image.jpg');

    $client = static::createClient();
    $client->request('POST', '/api/media_objects', [
        'headers' => ['Content-Type' => 'multipart/form-data'],
        'extra'   => ['files' => ['file' => $file]],
    ]);

    $this->assertResponseIsSuccessful();
    $this->assertMatchesResourceItemJsonSchema(\App\Entity\MediaObject::class);
}
```

Cf. `gerard:api-platform-file-upload`.

---

## 7. Coverage matrix — what to test on every operation

- **GET collection**: default order, `totalItems`, pagination.
- **GET item**: 200 + payload, 404 when missing.
- **POST**: 201 + payload, **422** on invalid payload.
- **PUT**: 200 + payload reflecting the replacement.
- **PATCH**: header `application/merge-patch+json`, partial update.
- **DELETE**: 204 + 404 on subsequent GET.
- **Auth**: 401 anonymous, 403 wrong role, 200/201 correct role.
- **Ownership**: owner can modify, other user → 403.
- **Filters**: each filter exercised with controlled data.
- **Pagination**: page size, next page, `view.next`/`view.previous` (no `hydra:` prefix in 4.x).
- **JSON schema**: `assertMatchesResourceItemJsonSchema`, `assertMatchesResourceCollectionJsonSchema`.

### Key examples

```php
// Validation 422
$this->assertResponseStatusCodeSame(422);
$this->assertJsonContains(['@type' => 'ConstraintViolationList']);

// PATCH with the correct Content-Type
static::createClient()->request('PATCH', '/api/products/'.$id, [
    'headers' => ['Content-Type' => 'application/merge-patch+json'],
    'json'    => ['name' => 'Patched Name'],
]);

// JWT-authenticated request
'auth_bearer' => $this->getToken($user->object()),

// Schema
$this->assertMatchesResourceItemJsonSchema(\App\Entity\Product::class);
```

---

## 8. Failure modes — exhaustive negative-test catalog

Every write operation has a finite set of failure modes that *must* be exercised. Missing one of these in the suite is how 5xx errors reach production. Run through this list when writing the test class for a new operation — coverage tools see green when these tests are missing (they only know "lines executed", not "negative paths exercised").

| Failure mode | HTTP | Trigger pattern |
|--------------|------|-----------------|
| Invalid payload | **422** | Submit a body that violates an `Assert\*` constraint. Assert `ConstraintViolationList` (`application/problem+json` when `rfc_7807_compliant_errors` is on). |
| Anonymous actor | **401** | Drop the JWT. Assert `WWW-Authenticate` is set. |
| Wrong role | **403** | Authenticate as a user whose role does not match the operation's `security`. |
| Boundary values | **422** / **200** | 0, negative, `null`, empty string, length overflow. One parametrized case per field. |
| Resource not found | **404** | GET / PUT / PATCH / DELETE on an identifier that does not exist. |
| Retry / partial failure (async) | varies | Messenger DLQ replay, idempotence-key replay, transport down → degraded mode. See `gerard:api-platform-resilience`. |
| Uniqueness / DB constraint clash | **409** *or* **422** | `UniqueEntity` collision, FK violation. Pick 409 or 422 once project-wide and stick to it. |
| Method not allowed | **405** | HTTP verb not declared on the resource. Assert the `Allow` header lists the supported verbs. |
| Wrong `Content-Type` | **415** | PATCH without `application/merge-patch+json`, POST with `text/plain`. |
| Circular serialization | **200** | A graph with a self-reference. Assert `MaxDepth` cuts the chain — without it the response is infinite. |

### Minimum mandatory quartet

A PR that adds a new write operation without at least the **422 + 401 + 403 + 404** quartet is rejected by `symfony-reviewer`. The other rows are mandatory whenever the operation involves uniqueness, multiple verbs, PATCH, or graph relations.

### Anti-regression — scenario-named tests

Wire one test per row using scenario-based naming (cf. §11):

```php
public function test_anonymous_cannot_post_order(): void { /* 401 */ }
public function test_payload_without_email_returns_422(): void { /* 422 */ }
public function test_unknown_id_returns_404_on_get(): void { /* 404 */ }
public function test_patch_without_merge_patch_content_type_returns_415(): void { /* 415 */ }
public function test_duplicate_email_returns_409(): void { /* 409 */ }
```

See `gerard:api-platform-errors` §8 for the upstream validation rules feeding the 422 path.

---

## 9. Foundry rules

- `use Factories;` to activate factories.
- `use ResetDatabase;` to start from a clean slate per test (the DAMA transaction approach is faster — see §1).
- `ProductFactory::createOne([...])` for targeted cases.
- `ProductFactory::createMany(30)` for collection tests.

---

## 10. Container access in tests

```php
$em = static::getContainer()->get('doctrine')->getManager();
```

Useful for assertions on persisted state when the response alone doesn't tell the full story.

---

## 11. Mandatory tooling and CI rules

### Tooling

- **`dama/doctrine-test-bundle`** — wraps every test in a rolled-back Doctrine transaction. Faster than `ResetDatabase`.
- **`brianium/paratest`** — runs the suite in parallel (`./vendor/bin/paratest -p8`). Essential once the suite exceeds 30s.
- **`PantherTestCase`** — real browser for JS, Stimulus, Turbo, modals (out of scope here; see Symfony testing docs).
- **`WebTestCase`** — kernel + crawler without JS, much faster for server-rendered pages.
- **`ApiTestCase`** — REST / JSON-LD endpoints.

### CI rules (blocking)

- **Unit-test coverage 100 % on domain classes** (entities, value objects, domain services, command handlers). The CI must fail if coverage drops (`phpunit --coverage-clover` + minimum threshold).
- **Functional tests are mandatory on every API endpoint.** No new route lands without an `ApiTestCase`. CI must check that every operation declared in `#[ApiResource]` is covered.
- **Every scenario must be tested**: happy path, 401, 403, 404, 422, conflicts, pagination, filters, ownership.

---

## 12. Scenario-based naming

Test methods describe the scenario in plain English:

```php
public function test_anonymous_user_cannot_create_order(): void
public function test_owner_can_update_their_own_order(): void
public function test_admin_can_delete_any_order(): void
public function test_invalid_payload_returns_422_with_violations(): void
public function test_collection_is_paginated_with_default_30_items(): void
```

A reader must understand what is tested without reading the body.

---

## 13. Maintainable test suite

- **Factories** (Foundry) — never build objects manually in tests.
- **One logical assertion per test** (one reason to fail).
- **No conditional logic** in tests (`if`, `switch` → split into two tests).
- **Shared helpers** in `tests/Support/` (auth, fixtures, custom assertions).
- **Group tests by functional context** (one file = one resource or one cohesive scenario).
- **No order dependency** — every test starts from a clean state (DAMA rollback or Foundry `ResetDatabase`).

---

## 14. Running the suite

```bash
./vendor/bin/phpunit
./vendor/bin/phpunit --filter=Api
./vendor/bin/paratest -p8                # parallel
./vendor/bin/paratest -p8 --coverage-clover coverage.xml
```

---

## 15. Related skills

- `gerard:api-platform-resources` — the operations under test.
- `gerard:api-platform-security` — auth setup (JWT, voters).
- `gerard:api-platform-user` — user fixtures, hash-light tests.
- `gerard:doctrine-fixtures-foundry` — Foundry factories, stories, sequences.
- `gerard:tdd-with-phpunit` — TDD cadence (RED → GREEN → REFACTOR).
- `gerard:functional-tests` — non-API HTTP tests (server-rendered pages).
- `gerard:quality-checks` — coverage thresholds, CI integration.
