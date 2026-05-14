---
name: tdd-php
description: >
  RED-GREEN-REFACTOR TDD on a Symfony 7.4+ project. Single skill, two
  framework variants — Pest or PHPUnit 12. The session-start hook detects
  the project's `test_framework` (from composer.lock) and exposes it as
  `test_framework: pest|phpunit` in the session JSON; this skill routes to
  the matching idioms (block syntax + expectations for Pest; attributes +
  `extends TestCase` for PHPUnit 12). Use Foundry factories for fixtures
  and DAMA Doctrine Test Bundle for transaction-rollback regardless of
  framework. Triggers: "write a Pest test", "write a PHPUnit test",
  "TDD this feature", "RED-GREEN-REFACTOR a service".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
effort:
  low: SKILL.md only — RED/GREEN/REFACTOR loop + framework-detected snippet.
  high: SKILL.md + reference.md — full doctrine (test pyramid, DAMA, Foundry, ParaTest, anti-patterns).
  xhigh: Above + Infection mutation testing + per-process DB strategy.
---

# TDD with Pest or PHPUnit (Symfony)

## Use when

- Building regression-safe behavior with TDD/functional/E2E tests.
- Converting a bug report into an executable failing test.
- Converting between Pest and PHPUnit (same RED/GREEN/REFACTOR shape, different syntax).

## Framework detection

The session-start hook injects `test_framework` into the session JSON:

- `test_framework: pest` → Pest is installed (composer.lock has `pestphp/pest`)
- `test_framework: phpunit` → default (PHPUnit only)

Route to the matching section below. If both are installed, prefer Pest (block syntax is more compact for new tests; existing PHPUnit tests stay as-is until you touch them).

## Default workflow

1. **RED** — write the failing test for target behavior + one boundary case. Run; confirm it fails for the *right reason* (class missing / behavior wrong, not a typo).
2. **GREEN** — minimal code to pass. No premature optimization.
3. **REFACTOR** — improve naming / structure while green. If a test breaks, you broke behavior — back off.
4. **Broaden** — invalid input / unauthorized / not-found paths.

## Skeletons

### Pest (when `test_framework: pest`)

```php
use App\Service\OrderService;
use App\Entity\Order;
use function Zenstruck\Foundry\Persistence\persist;

beforeEach(function () {
    $this->orderService = $this->getContainer()->get(OrderService::class);
});

it('creates an order for a user', function () {
    $user = persist(User::class);

    $order = $this->orderService->createOrder($user->object(), [
        ['productId' => 1, 'quantity' => 2],
    ]);

    expect($order)
        ->toBeInstanceOf(Order::class)
        ->and($order->getItems())->toHaveCount(1);
});

it('throws on empty items', function () {
    $user = persist(User::class);
    $this->orderService->createOrder($user->object(), []);
})->throws(InvalidArgumentException::class);
```

### PHPUnit 12 (when `test_framework: phpunit`)

```php
namespace App\Tests\Unit\Catalog\Application;

use App\Service\OrderService;
use PHPUnit\Framework\Attributes\CoversClass;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

#[CoversClass(OrderService::class)]
final class OrderServiceTest extends KernelTestCase
{
    public function test_it_creates_an_order_for_a_user(): void
    {
        $service = self::getContainer()->get(OrderService::class);
        $user = UserFactory::createOne();

        $order = $service->createOrder($user->object(), [
            ['productId' => 1, 'quantity' => 2],
        ]);

        self::assertCount(1, $order->getItems());
    }
}
```

PHPUnit 12 accepts both `test_business_behavior` (snake) and `testBusinessBehavior` (camel) — the only requirement is the method starts with `test`. Pick one style per project.

## Guardrails (both frameworks)

- **Deterministic fixtures/builders** — Foundry factories, not raw `new Entity()`.
- **Assert observable behavior**, not internal implementation (no `assertSame($x, $x)` tautology).
- **One concept per test** — chain related expectations (Pest) or one focused `assert*` cluster (PHPUnit).
- **Tests stay isolated** — DAMA Doctrine Test Bundle wraps each test in a rolled-back transaction.

## Output contract (what to report back)

- RED → GREEN → REFACTOR trace (briefly).
- Tests added (file:line) and executed command.
- Coverage on the touched surface + confidence note.

## Quick commands

```bash
# Pest
./vendor/bin/pest --parallel
./vendor/bin/pest --filter "creates order"

# PHPUnit
./vendor/bin/phpunit --testsuite=api
./vendor/bin/paratest -p auto --testsuite=api
```

Adjust the prefix (`./vendor/bin/`, `docker compose exec php`, `ddev exec`, `make tests`) per `runner_type` from the session-start hook.

## References

- `reference.md` — full doctrine (test pyramid, DAMA + Foundry combo, ParaTest, coverage thresholds, mutation testing with Infection, common assertions cheat sheet)
- `gerard:functional-tests` — `WebTestCase` for non-API HTTP
- `gerard:api-platform-tests` — `ApiTestCase` for API Platform endpoints (DAMA + schema assertions)
- `gerard:test-doubles-mocking` — fakes / stubs / mocks discipline
- `gerard:doctrine-fixtures-foundry` — Foundry factory patterns
- `gerard:quality-checks` — CI coverage threshold gate
