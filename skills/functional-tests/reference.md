# Functional tests (reference)


## 1. Stack

```bash
composer require --dev symfony/test-pack symfony/browser-kit symfony/css-selector
composer require --dev dama/doctrine-test-bundle zenstruck/foundry
composer require --dev brianium/paratest
```

### `phpunit.xml.dist` (DAMA hook)

```xml
<extensions>
    <bootstrap class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
</extensions>
```

---

## 2. Skeleton

```php
namespace App\Tests\Functional\Catalog;

use App\Tests\Factory\ProductFactory;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Zenstruck\Foundry\Test\Factories;
use Zenstruck\Foundry\Test\ResetDatabase;

final class ProductListTest extends WebTestCase
{
    use Factories;
    use ResetDatabase;

    public function test_listing_displays_all_products(): void
    {
        ProductFactory::createMany(3, ['name' => 'Widget']);

        $client = static::createClient();
        $crawler = $client->request('GET', '/products');

        $this->assertResponseIsSuccessful();
        $this->assertSelectorTextContains('h1', 'Products');
        $this->assertCount(3, $crawler->filter('.product-card'));
    }
}
```

---

## 3. Authenticated client

```php
use App\Entity\User;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;

private function loginAs(string $email): KernelBrowser
{
    $client = static::createClient();
    $user   = static::getContainer()->get(UserRepository::class)->findOneBy(['email' => $email]);
    $client->loginUser($user);

    return $client;
}

public function test_authenticated_user_sees_admin_panel(): void
{
    UserFactory::createOne(['email' => '[email protected]', 'roles' => ['ROLE_ADMIN']]);

    $client = $this->loginAs('[email protected]');
    $client->request('GET', '/admin');

    $this->assertResponseIsSuccessful();
    $this->assertSelectorTextContains('h1', 'Admin');
}
```

`KernelBrowser::loginUser()` bypasses the login form — useful when you want to test the *secured* page, not the *login* page itself.

---

## 4. Form submission + redirect

```php
public function test_creating_a_product_redirects_to_the_list(): void
{
    $client  = $this->loginAs('[email protected]');
    $crawler = $client->request('GET', '/products/new');

    $form = $crawler->selectButton('Create')->form([
        'product[name]'  => 'New widget',
        'product[price]' => '1999',
    ]);

    $client->submit($form);

    $this->assertResponseRedirects('/products');
    $client->followRedirect();
    $this->assertSelectorTextContains('.flash-success', 'Product created');
}
```

### Invalid form

```php
public function test_invalid_payload_shows_form_errors(): void
{
    $client  = $this->loginAs('[email protected]');
    $crawler = $client->request('GET', '/products/new');

    $form = $crawler->selectButton('Create')->form([
        'product[name]'  => '',          // required
        'product[price]' => '-100',      // must be positive
    ]);

    $client->submit($form);

    $this->assertResponseIsUnprocessable();   // 422 if your controller uses HTTP semantics
    $this->assertSelectorExists('.form-error');
}
```

---

## 5. CSRF

When CSRF is enabled, Symfony's form helper handles it automatically (the form fetched via the Crawler includes the token).

For non-form POST endpoints (custom CSRF protection), pass the token explicitly:

```php
$token = static::getContainer()->get('security.csrf.token_manager')->getToken('delete-item')->getValue();
$client->request('POST', '/items/42/delete', ['_token' => $token]);
```

A test that submits without the token should fail (proves CSRF is on).

---

## 6. Flash messages

```php
$this->assertSelectorTextContains('.flash-success', 'Saved');
$this->assertSelectorTextContains('.flash-error', 'Cannot delete');
```

---

## 7. Anonymous + forbidden paths

```php
public function test_anonymous_is_redirected_to_login(): void
{
    $client = static::createClient();
    $client->request('GET', '/admin');

    $this->assertResponseRedirects('/login');
}

public function test_non_admin_user_gets_403(): void
{
    UserFactory::createOne(['email' => '[email protected]', 'roles' => ['ROLE_USER']]);

    $client = $this->loginAs('[email protected]');
    $client->request('GET', '/admin');

    $this->assertResponseStatusCodeSame(403);
}
```

---

## 8. Lightweight password hashing in test env

Same trick as for API tests — `md5` in `config/packages/test/security.yaml` to speed user creation ×5 (cf. `gerard:api-platform-tests` §1).

---

## 9. Scenario-based naming

```php
public function test_anonymous_user_is_redirected_to_login_on_admin_route(): void
public function test_owner_can_publish_their_own_draft(): void
public function test_invalid_form_displays_csrf_error(): void
public function test_successful_creation_shows_success_flash(): void
```

A reader must understand what is tested from the method name alone.

---

## 10. ParaTest

```bash
./vendor/bin/paratest -p auto                          # auto-detect CPU
./vendor/bin/paratest -p8 --testsuite=functional
```

---

## 11. Best practices

- **DAMA over Foundry `ResetDatabase`** when both are available — DAMA transaction rollback is faster.
- **Factory pattern** (`Foundry`) over hand-built fixtures.
- **One logical assertion** per test (the test fails for a single reason).
- **No `if` / `switch`** inside tests — split into multiple methods.
- **Helpers in `tests/Support/`** for auth, fixtures, shared crawlers.
- **Group by functional context**: one file per feature or controller action.

---

## 12. Related skills

- `gerard:api-platform-tests` — REST / JSON-LD endpoints (`ApiTestCase`, schema assertions, JWT).
- `gerard:tdd-with-phpunit` — RED-GREEN-REFACTOR rhythm.
- `gerard:tdd-with-pest` — Pest-syntax alternative.
- `gerard:doctrine-fixtures-foundry` — Factory definitions.
- `gerard:symfony-voters` — assert authorization decisions via 403 / redirect.
- `gerard:quality-checks` — ParaTest, coverage thresholds, CI integration.
