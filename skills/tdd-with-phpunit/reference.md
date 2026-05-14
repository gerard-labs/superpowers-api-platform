# TDD with PHPUnit 12 (reference)

> Companion to `SKILL.md`. PHPUnit 12 + Symfony 7.4+ test stack.

## 1. Stack

```bash
composer require --dev symfony/test-pack dama/doctrine-test-bundle zenstruck/foundry brianium/paratest
```

### `phpunit.dist.xml`

```xml
<phpunit
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
    bootstrap="vendor/autoload.php"
    colors="true"
    failOnWarning="true"
    cacheDirectory=".phpunit.cache"
>
    <php>
        <ini name="memory_limit" value="-1"/>
        <env name="APP_ENV" value="test" force="true"/>
    </php>

    <testsuites>
        <testsuite name="unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="functional">
            <directory>tests/Functional</directory>
        </testsuite>
        <testsuite name="api">
            <directory>tests/Functional/Api</directory>
        </testsuite>
    </testsuites>

    <source>
        <include>
            <directory>src</directory>
        </include>
        <exclude>
            <directory>src/DataFixtures</directory>
            <directory>src/Migrations</directory>
        </exclude>
    </source>

    <extensions>
        <bootstrap class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
    </extensions>
</phpunit>
```

## 2. RED-GREEN-REFACTOR cycle

### RED — write the failing test first

```php
namespace App\Tests\Unit\Catalog\Domain;

use App\Catalog\Domain\Product;
use App\Catalog\Domain\Sku;
use App\Catalog\Domain\Money;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

#[CoversClass(Product::class)]
final class ProductTest extends TestCase
{
    public function test_a_product_is_created_with_a_sku_and_price(): void
    {
        $product = new Product(Sku::fromString('SKU-001'), Money::of(1000, 'EUR'));

        self::assertSame('SKU-001', $product->sku()->value());
        self::assertSame(1000, $product->price()->amount());
    }
}
```

Run :

```bash
./vendor/bin/phpunit --filter=ProductTest
```

Expected output : `Error: Class "App\Catalog\Domain\Product" not found`. **The test must fail for the right reason** (class doesn't exist, not a typo in the test).

### GREEN — minimal implementation

```php
namespace App\Catalog\Domain;

final readonly class Product
{
    public function __construct(
        private Sku $sku,
        private Money $price,
    ) {}

    public function sku(): Sku { return $this->sku; }
    public function price(): Money { return $this->price; }
}
```

Run again. Test passes.

### REFACTOR — clean up while green

Improve naming, extract methods, eliminate duplication. **Tests stay green**. If a test breaks, you broke behavior — back off.

## 3. PHPUnit 12 — test naming styles

**Both styles accepted** (PHPUnit 12 only requires the method to start with `test`):

- ✓ `test_rejects_payment_when_card_expired` (BDD snake_case)
- ✓ `testRejectsPaymentWhenCardExpired` (BDD camelCase)
- ✗ `testCalculateReturnsValue` (implementation style)
- ✗ `testFooBar1` (generic)

The rule : describe **business behavior**, not implementation. Pick a style per project and stay consistent.

## 4. Test types — pyramid

```
       ┌─────────┐ E2E (Panther / Playwright) — ~3 %
      ┌─┴────────┴┐
     ┌┴ ApiTest ─┴┐  ApiTestCase — ~7 % (cf. gerard:api-platform-tests)
    ┌┴ Functional ┴┐  WebTestCase — ~20 % (cf. gerard:functional-tests)
   ┌┴───── Unit ───┴┐  TestCase — ~70 %
   └────────────────┘
```

Inversion = code smell. Too much integration = uninstable code (collaborators too coupled, concrete deps).

## 5. Unit test pattern (Domain layer)

```php
namespace App\Tests\Unit\Catalog\Domain;

use App\Catalog\Domain\Email;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

#[CoversClass(Email::class)]
final class EmailTest extends TestCase
{
    #[DataProvider('validEmails')]
    public function test_email_accepts_valid_format(string $value): void
    {
        $email = Email::fromString($value);
        self::assertSame($value, $email->value());
    }

    public static function validEmails(): iterable
    {
        yield 'simple' => ['[email protected]'];
        yield 'subdomain' => ['[email protected]'];
        yield 'plus addressing' => ['[email protected]'];
    }

    #[DataProvider('invalidEmails')]
    public function test_email_rejects_invalid_format(string $value): void
    {
        $this->expectException(\InvalidArgumentException::class);
        Email::fromString($value);
    }

    public static function invalidEmails(): iterable
    {
        yield 'no @' => ['notanemail'];
        yield 'no domain' => ['user@'];
        yield 'empty' => [''];
    }
}
```

PHPUnit 12 prefers **attributes** over docblocks : `#[DataProvider]`, `#[CoversClass]`, `#[Group]`, `#[Depends]`.

## 6. KernelTestCase — services with the container

```php
namespace App\Tests\Integration\Catalog\Application;

use App\Catalog\Application\CreateProductHandler;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

final class CreateProductHandlerTest extends KernelTestCase
{
    public function test_it_creates_and_persists_a_product(): void
    {
        $handler = self::getContainer()->get(CreateProductHandler::class);
        $product = $handler(new CreateProduct(/* ... */));

        self::assertNotNull($product->id());
        // ...
    }
}
```

With DAMA + Foundry, every test runs in a transaction that rolls back at teardown.

## 7. WebTestCase — controllers + HTTP

```php
namespace App\Tests\Functional\Catalog;

use App\Tests\Factory\UserFactory;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Zenstruck\Foundry\Test\Factories;
use Zenstruck\Foundry\Test\ResetDatabase;

final class ProductListControllerTest extends WebTestCase
{
    use Factories;
    use ResetDatabase;

    public function test_admin_can_see_product_list(): void
    {
        UserFactory::createOne(['email' => '[email protected]', 'roles' => ['ROLE_ADMIN']]);
        $client = static::createClient();
        $client->loginUser(static::getContainer()->get(UserRepository::class)->findOneBy(['email' => '[email protected]']));

        $client->request('GET', '/admin/products');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'Products');
    }
}
```

For API endpoints, prefer `ApiTestCase` — see `gerard:api-platform-tests`.

## 8. DAMA + Foundry combo

`DAMA\DoctrineTestBundle` wraps every test in a Doctrine transaction that rolls back at teardown. **Way faster** than `Foundry`'s `ResetDatabase` (no schema drop/create per test).

Hook it in `phpunit.dist.xml` :

```xml
<extensions>
    <bootstrap class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
</extensions>
```

Use `Factories` trait without `ResetDatabase` when DAMA is on.

## 9. ParaTest — parallel runs

Once the suite exceeds 30 seconds, parallel runs become essential :

```bash
./vendor/bin/paratest -p auto                         # auto-detect CPU
./vendor/bin/paratest -p8 --testsuite=api             # 8 processes
./vendor/bin/paratest -p auto --coverage-clover coverage.xml
```

Each process needs an isolated test DB. With `dama/doctrine-test-bundle` + Doctrine's `dbname_suffix` :

```yaml
# config/packages/test/doctrine.yaml
doctrine:
    dbal:
        dbname_suffix: '_test%env(default::TEST_TOKEN)%'
```

```bash
# Prepare per-process DBs once
for token in "" 1 2 3 4; do
    php bin/console doctrine:database:create --env=test --if-not-exists -- ${token}
    php bin/console doctrine:migrations:migrate --env=test --no-interaction
done
```

## 10. Coverage — `--coverage-clover` with threshold

```bash
./vendor/bin/phpunit --coverage-clover coverage.xml --coverage-text
```

Enforce in CI :

```bash
./vendor/bin/coverage-check coverage.xml 90    # fails if line coverage < 90
```

For domain layer, target **100%** classes + methods.

## 11. Anti-patterns to reject

- **Tautological test** — `assertSame($service->calc($x), $service->calc($x))` — passes with AND without prod code. Mutation testing catches them (cf. `gerard:api-platform-tests` §10).
- **Test names mimicking implementation** — `testGetUserCallsRepository`, `testHandlerInvokesBus` — should describe behavior, not call chain.
- **Tests with setup so long the assertion is invisible** — extract a builder or a Foundry factory.
- **20 parameterized cases on the same branch** under different names — property-based test would be stronger.
- **Mocks of every collaborator** — use Fakes / Stubs / Mocks deliberately (cf. `gerard:test-doubles-mocking`).
- **`markTestSkipped()` without follow-up ticket** — fix now or open issue and link.
- **One assertion physical, many assertions logical** — split into focused tests.

## 12. Mutation testing (Infection)

```bash
composer require --dev infection/infection
./vendor/bin/infection --threads=4 --min-msi=80 --min-covered-msi=85
```

Run per-target on critical classes :

```bash
./vendor/bin/infection --filter=src/Catalog/Domain/Money.php
```

Critical classes for MSI ≥ 80 % : value objects with invariants, aggregates, command handlers, processors that mutate state, voters, finance/rights/PII code.

Cf. `gerard:api-platform-tests` for the full mutation strategy.

## 13. Test-only password hashing

`config/packages/test/security.yaml` :

```yaml
security:
    password_hashers:
        App\Entity\User:
            algorithm:        md5
            encode_as_base64: false
            iterations:       0
```

Speeds the suite ×5 once you have user creations.

## 14. Common assertions cheat sheet

```php
// HTTP
self::assertResponseIsSuccessful();
self::assertResponseStatusCodeSame(201);
self::assertResponseRedirects('/login');
self::assertSelectorTextContains('h1', 'Welcome');

// Form errors
self::assertSelectorExists('.form-error');
self::assertSelectorTextContains('.form-error', 'is required');

// API (cf. gerard:api-platform-tests)
self::assertResponseHeaderSame('content-type', 'application/ld+json; charset=utf-8');
self::assertJsonContains(['@type' => 'Collection', 'totalItems' => 30]);
self::assertMatchesResourceItemJsonSchema(Product::class);

// Container
$service = self::getContainer()->get(MyService::class);

// Container parameter
$param = self::getContainer()->getParameter('app.foo');
```

## 15. Validation commands

```bash
./vendor/bin/phpunit
./vendor/bin/phpunit --filter=Unit
./vendor/bin/phpunit --testsuite=api
./vendor/bin/paratest -p auto
./vendor/bin/infection --threads=4
```

## 16. Related skills

- `gerard:tdd-with-pest` — Pest-syntax alternative
- `gerard:functional-tests` — `WebTestCase` for non-API HTTP
- `gerard:api-platform-tests` — `ApiTestCase` + DAMA + schema assertions
- `gerard:test-doubles-mocking` — fakes / stubs / mocks discipline
- `gerard:doctrine-fixtures-foundry` — Foundry factories
- `gerard:quality-checks` — coverage threshold + CI integration
