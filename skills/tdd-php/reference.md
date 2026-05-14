# TDD with Pest or PHPUnit (reference)

> Companion to `SKILL.md`. Full doctrine for both frameworks. Routes by the `test_framework` field exposed by the session-start hook.

## 1. Stack

### Pest

```bash
composer require pestphp/pest --dev --with-all-dependencies
composer require pestphp/pest-plugin-symfony --dev
composer require zenstruck/foundry --dev
./vendor/bin/pest --init
```

### PHPUnit 12

```bash
composer require --dev symfony/test-pack dama/doctrine-test-bundle zenstruck/foundry brianium/paratest
```

### Shared `phpunit.dist.xml` (used by PHPUnit directly AND by Pest under the hood)

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

## 2. Test pyramid

```
       ┌─────────┐ E2E (Panther / Playwright) — ~3 %
      ┌─┴────────┴┐
     ┌┴ ApiTest ─┴┐  ApiTestCase — ~7 % (cf. gerard:api-platform-tests)
    ┌┴ Functional ┴┐  WebTestCase — ~20 % (cf. gerard:functional-tests)
   ┌┴───── Unit ───┴┐  TestCase — ~70 %
   └────────────────┘
```

Inversion = code smell. Too much integration = unstable code (collaborators too coupled, concrete deps).

## 3. RED-GREEN-REFACTOR — full cycle

### Pest variant

```php
// tests/Unit/Service/OrderServiceTest.php
use App\Service\OrderService;
use App\Entity\Order;
use App\Entity\User;
use function Zenstruck\Foundry\Persistence\persist;

beforeEach(function () {
    $this->orderService = $this->getContainer()->get(OrderService::class);
});

it('creates an order for a user', function () {
    $user = persist(User::class, ['email' => '[email protected]']);

    $order = $this->orderService->createOrder($user->object(), [
        ['productId' => 1, 'quantity' => 2],
    ]);

    expect($order)
        ->toBeInstanceOf(Order::class)
        ->and($order->getCustomer())->toBe($user->object())
        ->and($order->getItems())->toHaveCount(1);
});

it('throws exception for empty items', function () {
    $user = persist(User::class);
    $this->orderService->createOrder($user->object(), []);
})->throws(InvalidArgumentException::class, 'Order must have at least one item');
```

### PHPUnit 12 variant

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

Run each — first failure should be **"class doesn't exist"** (right reason), not a syntax error in the test itself. Then add the minimal class to flip it green.

## 4. PHPUnit 12 — naming styles

**Both styles accepted** (PHPUnit 12 only requires the method to start with `test`):

- ✓ `test_rejects_payment_when_card_expired` (BDD snake_case)
- ✓ `testRejectsPaymentWhenCardExpired` (BDD camelCase)
- ✗ `testCalculateReturnsValue` (implementation style)
- ✗ `testFooBar1` (generic)

Rule : describe **business behavior**, not implementation. Pick a style per project and stay consistent.

## 5. Pest — block flavors and expectations

### Test blocks

```php
test('it creates an order', function () { /* ... */ });
it('creates an order',     function () { /* ... */ });   // BDD-flavored alias
describe('OrderService', function () {
    it('creates an order', function () { /* ... */ });
});
```

### Setup / teardown

```php
beforeEach(function () { /* ... */ });
afterEach(function ()  { /* ... */ });
beforeAll(function ()  { /* ... */ });
afterAll(function ()   { /* ... */ });
```

### Datasets (parameterized tests)

```php
it('rejects invalid emails', function (string $email) {
    expect(fn() => Email::fromString($email))->toThrow(\InvalidArgumentException::class);
})->with(['', 'notanemail', 'user@', '@domain']);
```

### Expectation pipeline

```php
expect($value)->toBe($expected);
expect($value)->toEqual($expected);
expect($value)->toBeTrue();
expect($value)->toBeFalse();
expect($value)->toBeNull();
expect($value)->toBeEmpty();
expect($value)->toBeInstanceOf(Order::class);
expect($value)->toBeArray();

// Arrays
expect($array)->toHaveCount(3);
expect($array)->toHaveKey('id');
expect($array)->toContain($item);

// Strings
expect($string)->toContain('substring');
expect($string)->toStartWith('prefix');
expect($string)->toMatch('/pattern/');

// Chaining (the core Pest idiom)
expect($order)
    ->toBeInstanceOf(Order::class)
    ->and($order->getStatus())->toBe(OrderStatus::PENDING)
    ->and($order->getItems())->toHaveCount(2);
```

### Higher-order tests

```php
test('it has a valid SKU')
    ->expect(fn() => Product::create('SKU-001'))
    ->toBeInstanceOf(Product::class)
    ->sku()->value()->toBe('SKU-001');
```

### Pest plugins worth knowing

- `pest-plugin-faker` — `fake()->email()` inline in expectations.
- `pest-plugin-stress` — stress tests under the same harness.
- `pest-plugin-snapshot` — snapshot testing for complex DTO outputs.

## 6. PHPUnit 12 — attributes over docblocks

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
        yield 'simple'    => ['[email protected]'];
        yield 'subdomain' => ['[email protected]'];
        yield 'plus'      => ['[email protected]'];
    }

    #[DataProvider('invalidEmails')]
    public function test_email_rejects_invalid_format(string $value): void
    {
        $this->expectException(\InvalidArgumentException::class);
        Email::fromString($value);
    }

    public static function invalidEmails(): iterable
    {
        yield 'no @'      => ['notanemail'];
        yield 'no domain' => ['user@'];
        yield 'empty'     => [''];
    }
}
```

PHPUnit 12 prefers `#[DataProvider]`, `#[CoversClass]`, `#[Group]`, `#[Depends]` over `@dataProvider`-style docblocks.

## 7. KernelTestCase — services + container

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
    }
}
```

With DAMA + Foundry, every test runs in a transaction that rolls back at teardown.

## 8. WebTestCase — controllers + HTTP

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
        $client->loginUser(
            static::getContainer()->get(UserRepository::class)->findOneBy(['email' => '[email protected]'])
        );

        $client->request('GET', '/admin/products');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'Products');
    }
}
```

For API endpoints, prefer `ApiTestCase` — see `gerard:api-platform-tests`.

## 9. DAMA + Foundry combo

`DAMA\DoctrineTestBundle` wraps every test in a Doctrine transaction that rolls back at teardown. **Way faster** than `Foundry`'s `ResetDatabase` (no schema drop/create per test).

Hook in `phpunit.dist.xml` :

```xml
<extensions>
    <bootstrap class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
</extensions>
```

Use the `Factories` trait without `ResetDatabase` once DAMA is on.

## 10. Foundry — factory pattern

```php
namespace App\Tests\Factory;

use App\Entity\User;
use Zenstruck\Foundry\Persistence\PersistentProxyObjectFactory;

final class UserFactory extends PersistentProxyObjectFactory
{
    public static function class(): string
    {
        return User::class;
    }

    protected function defaults(): array
    {
        return [
            'email'    => self::faker()->unique()->email(),
            'password' => 'hashed_password',
            'roles'    => ['ROLE_USER'],
        ];
    }

    public function admin(): self
    {
        return $this->with(['roles' => ['ROLE_ADMIN']]);
    }
}
```

Usage :

```php
$user   = UserFactory::createOne();
$admin  = UserFactory::createOne()->admin();
$users  = UserFactory::createMany(5);
$noPersist = UserFactory::new()->withoutPersisting()->create();
```

## 11. ParaTest — parallel runs

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

Pest uses the same harness — `./vendor/bin/pest --parallel` invokes ParaTest under the hood.

## 12. Coverage threshold

```bash
./vendor/bin/phpunit --coverage-clover coverage.xml --coverage-text
./vendor/bin/pest    --coverage --min=80
```

Enforce in CI :

```bash
./vendor/bin/coverage-check coverage.xml 90    # fails if line coverage < 90
```

For domain layer, target **100%** classes + methods.

## 13. Mutation testing (Infection)

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

## 14. Anti-patterns to reject (both frameworks)

- **Tautological test** — `assertSame($service->calc($x), $service->calc($x))` — passes with AND without prod code. Mutation testing catches them.
- **Test names mimicking implementation** — `testGetUserCallsRepository`, `testHandlerInvokesBus` — should describe behavior, not the call chain.
- **Setup so long the assertion is invisible** — extract a builder or a Foundry factory.
- **20 parameterized cases on the same branch** — property-based testing would be stronger.
- **Mock every collaborator** — use Fakes / Stubs / Mocks deliberately (cf. `gerard:test-doubles-mocking`).
- **`markTestSkipped()` / `it('foo')->skip()` without a follow-up ticket** — fix now or open issue and link.
- **One physical `assert*`, many logical assertions** — split into focused tests (or use a single `expect()->chain` for tightly-coupled invariants).

## 15. Test-only password hashing

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

## 16. Common assertions cheat sheet (PHPUnit)

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
$param   = self::getContainer()->getParameter('app.foo');
```

For Pest, wrap them as `expect()` macros if you prefer the pipeline style.

## 17. Validation commands

```bash
# Detection
grep -q 'pestphp/pest' composer.lock && echo pest || echo phpunit

# Pest
./vendor/bin/pest
./vendor/bin/pest --parallel
./vendor/bin/pest --filter "creates order"
./vendor/bin/pest --coverage --min=80

# PHPUnit
./vendor/bin/phpunit
./vendor/bin/phpunit --filter=Unit
./vendor/bin/phpunit --testsuite=api
./vendor/bin/paratest -p auto
./vendor/bin/infection --threads=4
```

Adjust the prefix for the project's `runner_type` (`make`, `ddev exec`, `docker compose exec php`, raw host).

## 18. Skill operating checklist

### Design checklist (apply to every TDD task)

- Confirm operation boundaries + invariants first.
- Minimize scope while preserving contract correctness.
- Test both happy path AND negative path.
- One assertion concept per test (chain related expects).

### Failure modes to test

- Invalid payload or forbidden actor.
- Boundary values / not-found cases.
- Retry or partial-failure behavior for async flows.

## 19. Related skills

- `gerard:functional-tests` — `WebTestCase` for non-API HTTP
- `gerard:api-platform-tests` — `ApiTestCase` + DAMA + schema assertions
- `gerard:test-doubles-mocking` — fakes / stubs / mocks discipline
- `gerard:doctrine-fixtures-foundry` — Foundry factories
- `gerard:quality-checks` — coverage threshold + CI integration
