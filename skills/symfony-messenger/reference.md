# Symfony Messenger (reference)

> Companion to `SKILL.md`. Symfony 7.4+ Messenger component.

## 1. Install

```bash
composer require symfony/messenger
```

Auto-creates `config/packages/messenger.yaml`.

## 2. Basic message + handler

```php
// src/Message/SendWelcomeEmail.php
namespace App\Message;

final readonly class SendWelcomeEmail
{
    public function __construct(
        public string $userEmail,
        public string $locale,
    ) {}
}
```

```php
// src/MessageHandler/SendWelcomeEmailHandler.php
namespace App\MessageHandler;

use App\Message\SendWelcomeEmail;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;

#[AsMessageHandler]
final readonly class SendWelcomeEmailHandler
{
    public function __construct(private MailerInterface $mailer) {}

    public function __invoke(SendWelcomeEmail $message): void
    {
        $this->mailer->send(
            (new Email())
                ->to($message->userEmail)
                ->subject('Welcome')
                ->text('Hello !'),
        );
    }
}
```

Dispatch from anywhere:

```php
$bus->dispatch(new SendWelcomeEmail('[email protected]', 'fr'));
```

## 3. Bus configuration — sync, command, query, event

```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        buses:
            command.bus:
                middleware:
                    - validation
                    - doctrine_transaction
                    - doctrine_close_connection
            query.bus:
                middleware:
                    - validation
            event.bus:
                default_middleware:
                    allow_no_handlers: true
                    allow_no_senders: true
```

Inject the specific bus:

```php
public function __construct(
    #[Target('command.bus')] private MessageBusInterface $commandBus,
    #[Target('query.bus')]   private MessageBusInterface $queryBus,
) {}
```

## 4. Transports — sync vs async

```yaml
framework:
    messenger:
        transports:
            sync: 'sync://'

            async_doctrine:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'   # doctrine://default

            async_redis:
                dsn: 'redis://localhost:6379/messages'

            async_amqp:
                dsn: '%env(RABBITMQ_DSN)%'

            failed:
                dsn: 'doctrine://default?queue_name=failed'

        routing:
            App\Message\SendWelcomeEmail: async_doctrine
            App\Message\ImportProducts:   async_amqp
            App\Query\GetUserPreferences: sync     # query stays sync
```

**Rule of thumb** : commands (writes) → async. Queries (reads) → sync. Domain events → either depending on semantics.

## 5. Retry strategy + failure transport

```yaml
framework:
    messenger:
        transports:
            async_erp:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                retry_strategy:
                    max_retries: 5
                    delay: 1000          # 1s
                    multiplier: 2        # 1s → 2s → 4s → 8s → 16s
                    max_delay: 60000     # cap at 60s
                failure_transport: failed

            failed:
                dsn: 'doctrine://default?queue_name=failed'
```

CLI tools:

```bash
php bin/console messenger:failed:show
php bin/console messenger:failed:retry <id>
php bin/console messenger:failed:remove <id>
```

Cf. `gerard:messenger-retry-failures` for the deeper pattern.

## 6. Worker

```bash
php bin/console messenger:consume async_doctrine async_erp --limit=10 --time-limit=3600 --memory-limit=128M
```

Per-environment recommendation :

| Environment | Strategy |
|---|---|
| Dev | One terminal per transport, no `--limit` |
| CI | `--limit=1 --time-limit=10` to drain pending |
| Production | Supervisor / systemd service with `--time-limit=3600 --memory-limit=128M` (graceful auto-restart) |

## 7. Stamps — envelope metadata

```php
use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\Stamp\DelayStamp;
use Symfony\Component\Messenger\Stamp\AmqpStamp;

$envelope = new Envelope(new SendReport(), [
    new DelayStamp(60_000),                // delay 60s
    new AmqpStamp('low-priority'),         // routing key
]);
$bus->dispatch($envelope);
```

Common stamps :
- `DelayStamp(ms)` — schedule
- `BusNameStamp('command.bus')`
- `HandledStamp` — for `$result = $bus->dispatch(...)->last(HandledStamp::class)?->getResult()`
- `TransportNamesStamp(['async_erp'])`

## 8. Custom middleware

```php
namespace App\Messenger\Middleware;

use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\Middleware\MiddlewareInterface;
use Symfony\Component\Messenger\Middleware\StackInterface;

final class CorrelationIdMiddleware implements MiddlewareInterface
{
    public function handle(Envelope $envelope, StackInterface $stack): Envelope
    {
        // Tag every message with a correlation ID for log tracing
        if (!$envelope->last(CorrelationIdStamp::class)) {
            $envelope = $envelope->with(new CorrelationIdStamp(bin2hex(random_bytes(16))));
        }
        return $stack->next()->handle($envelope, $stack);
    }
}
```

Register in services.yaml:

```yaml
services:
    App\Messenger\Middleware\CorrelationIdMiddleware: ~
```

Add to bus:

```yaml
framework:
    messenger:
        buses:
            command.bus:
                middleware:
                    - App\Messenger\Middleware\CorrelationIdMiddleware
                    - doctrine_transaction
```

## 9. API Platform 4.3 native Messenger mode

API Platform 4.3 exposes a native `messenger:` option on operations — no custom Processor needed for fire-and-forget :

```php
use ApiPlatform\Metadata\Post;

#[Post(
    messenger: 'input',          // dispatch the Input DTO as a message
    input:     CreateOrderInput::class,
    output:    false,             // no response payload
    status:    202,                // 202 Accepted
)]
class Order { /* ... */ }
```

Cf. `gerard:api-platform-state-processors` for the bridging patterns.

## 10. CQRS bridge (manual)

```php
use Symfony\Component\Messenger\HandleTrait;
use Symfony\Component\Messenger\MessageBusInterface;

final readonly class CreateOrderService
{
    use HandleTrait;   // provides $this->handle() → returns result

    public function __construct(MessageBusInterface $commandBus)
    {
        $this->messageBus = $commandBus;
    }

    public function create(CreateOrderInput $input): Order
    {
        return $this->handle(new CreateOrder($input));   // dispatch + extract HandledStamp result
    }
}
```

## 11. Testing handlers

```php
namespace App\Tests\MessageHandler;

use App\Message\SendWelcomeEmail;
use App\MessageHandler\SendWelcomeEmailHandler;
use PHPUnit\Framework\TestCase;

final class SendWelcomeEmailHandlerTest extends TestCase
{
    public function test_it_sends_email_with_user_locale(): void
    {
        $mailer = $this->createMock(MailerInterface::class);
        $mailer->expects($this->once())
            ->method('send')
            ->with($this->callback(fn (Email $e) => $e->getTo()[0]->getAddress() === '[email protected]'));

        (new SendWelcomeEmailHandler($mailer))(new SendWelcomeEmail('[email protected]', 'fr'));
    }
}
```

For functional tests with the bus, use `TraceableMessageBus` (auto-wired in test env) to assert dispatch :

```php
$client = static::createClient();
$client->request('POST', '/api/orders', ['json' => [...]]);

$bus = static::getContainer()->get('messenger.bus.command.traceable');
$dispatched = $bus->getDispatchedMessages();
$this->assertCount(1, $dispatched);
$this->assertInstanceOf(CreateOrder::class, $dispatched[0]['message']);
```

## 12. Anti-patterns

- ❌ Long-running handler without timeout / memory limit → worker dies / drains memory
- ❌ Handler that does multiple unrelated things → split into multiple commands
- ❌ Dispatching from inside a handler without thinking about retry semantics
- ❌ `validation` middleware on the query bus → useless overhead (queries are reads)
- ❌ Forgetting `doctrine_close_connection` middleware → stale connection after long worker idle
- ❌ Domain events with no consumer → drop the event (cf. `gerard:cqrs-and-handlers`)

## 13. Validation commands

```bash
# Show registered handlers
php bin/console debug:messenger

# Consume one message and exit
php bin/console messenger:consume async_doctrine --limit=1

# Inspect failed
php bin/console messenger:failed:show
php bin/console messenger:failed:retry <id>

# Test pattern: dispatch sync in tests
php bin/console messenger:consume async_doctrine --limit=10 --time-limit=10 --no-reset
```

## 14. Related skills

- `gerard:messenger-retry-failures` — retry strategies, DLQ
- `gerard:symfony-scheduler` — recurring tasks via Messenger
- `gerard:cqrs-and-handlers` — Command/Query separation patterns
- `gerard:api-platform-state-processors` — bridge an API Platform write to Messenger
- `gerard:api-platform-resilience` — Circuit Breaker, async writes, degraded mode
