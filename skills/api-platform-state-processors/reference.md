# API Platform 4.3 — State Processors (reference)

## 1. Role

Turn an API representation (typically a DTO Input) into a side effect: persistence, event dispatch, call to an application service. The Processor is the **write** pipeline; the Provider is the read pipeline.

## 2. Scaffolding

```bash
php bin/console make:state-processor          # generates a skeleton in src/State/
```

## 3. Core rules

- **One Processor per operation** (e.g. `CreateOrderProcessor`, `CancelOrderProcessor`) or per use case.
- **No business logic in the Processor.** It orchestrates an application service or a CQRS handler.
- **Wrap multi-entity writes in a transaction** (`EntityManager::wrapInTransaction` or the `doctrine_transaction` middleware on the CQRS bus).
- **POST** → return the created entity / DTO so API Platform emits a 201 + `Location` header.
- **DELETE** → return `null` so API Platform emits a 204.
- **Tag**: `api_platform.state_processor` (auto-tagged when autoconfigure is on).
- **Decorate, do not replace** the Doctrine persist / remove Processor when you just need a hook before / after persistence.
- **Discriminate `DeleteOperationInterface`** to route to `remove_processor` (vs `persist_processor` for Post / Put / Patch).

---

## 4. CQRS bridging (manual)

Keep the Processor thin — dispatch a `Command` on a bus and return the result.

```php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Messenger\HandleTrait;
use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\Stamp\HandledStamp;

final readonly class CreateOrderProcessor implements ProcessorInterface
{
    public function __construct(private MessageBusInterface $commandBus) {}

    public function process(mixed $data, Operation $op, array $uriVars = [], array $ctx = []): object
    {
        // $data->customer is already the resolved Customer entity from the IRI.
        $envelope = $this->commandBus->dispatch(new CreateOrder(
            customer: $data->customer,
            items:    $data->items,
        ));

        /** @var HandledStamp $handled */
        $handled = $envelope->last(HandledStamp::class);
        return $handled->getResult();
    }
}
```

The `doctrine_transaction` middleware on the bus guarantees atomicity of the command handler.

---

## 5. Native Messenger integration (API Platform)

For operations that are **purely asynchronous** (send to an ERP, long computation, PDF generation), API Platform exposes a **native Messenger mode** through an operation option — no custom Processor required.

```php
use ApiPlatform\Metadata\Post;

#[Post(
    messenger: 'input',          // dispatch the Input DTO as a message
    input:     CreateOrderInput::class,
    output:    false,             // no response payload to serialize
    status:    202,                // 202 Accepted (not 201)
)]
class Order { /* ... */ }
```

Modes:

- **`messenger: true`** — dispatch the **resource** itself.
- **`messenger: 'input'`** — dispatch the **Input DTO** (cleaner: the message represents the business intent).

The handler is a regular `#[AsMessageHandler]`:

```php
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final readonly class CreateOrderHandler
{
    public function __invoke(CreateOrderInput $input): void
    {
        // Async execution by the worker.
    }
}
```

### Usage rules

- Use **HTTP 202** (`status: 202`) — semantically "received, in progress".
- **`output: false`** when no resource is returned immediately (nothing to serialize).
- For **Doctrine persist + async dispatch**, **decorate `persist_processor`** (see §6). Do not use `messenger: true`, which bypasses Doctrine entirely.

---

## 6. Decorating the Doctrine persist / remove processor (modern pattern)

Wrap the default persist / remove pipeline with before / after logic via `#[Autowire(service: ...)]`.

```php
use ApiPlatform\Doctrine\Common\State\PersistProcessor;
use ApiPlatform\Metadata\DeleteOperationInterface;
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\Messenger\MessageBusInterface;

final readonly class OrderProcessor implements ProcessorInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private ProcessorInterface $persist,
        #[Autowire(service: 'api_platform.doctrine.orm.state.remove_processor')]
        private ProcessorInterface $remove,
        private MessageBusInterface $bus,
    ) {}

    public function process(mixed $data, Operation $op, array $uri = [], array $ctx = []): mixed
    {
        if ($op instanceof DeleteOperationInterface) {
            return $this->remove->process($data, $op, $uri, $ctx);
        }

        $result = $this->persist->process($data, $op, $uri, $ctx);

        // Async side effect (e.g. notify the ERP).
        $this->bus->dispatch(new PlaceOrderInErp($result->getId()));

        return $result;
    }
}
```

Wire it on the operation:

```php
new Post(processor: OrderProcessor::class),
new Delete(processor: OrderProcessor::class),
```

---

## 7. Transactional integrity

For a single-entity write, the Doctrine persist processor already wraps the flush in a transaction. For **multi-entity** writes (`OrderProcessor` persisting an Order + multiple OrderItems via cascade is fine; but persisting two unrelated entities is not), wrap explicitly:

```php
$this->em->wrapInTransaction(function () use ($data) {
    $this->em->persist($data);
    $this->em->persist($auditLog);
});
```

Or — if using CQRS — rely on the bus middleware:

```yaml
framework:
    messenger:
        buses:
            command.bus:
                middleware:
                    - doctrine_transaction
                    - doctrine_close_connection
```

The Processor stays thin; transactional integrity lives on the bus.

---

## 8. Common mistakes to avoid

- **Business logic inside the Processor.** Push it into a service or a CQRS handler.
- **Forgetting to return the entity** on POST — API Platform cannot emit the `Location` header without it.
- **Returning the entity on DELETE** — must be `null` for the 204.
- **Using `messenger: true` for "persist + async"** — it bypasses Doctrine. Decorate `persist_processor` instead.
- **Catching exceptions silently** — let domain exceptions bubble up; API Platform maps them via `exceptionToStatus` (cf. `gerard:api-platform-errors`).

---

## 9. Validation commands

```bash
php bin/console debug:router | grep api
./vendor/bin/phpunit --filter=Processor
./vendor/bin/paratest -p8

# Confirm Messenger workers if you use the native async mode
php bin/console messenger:consume --limit=1 async_default
php bin/console messenger:failed:show
```

---

## 10. Related skills

- `gerard:api-platform-resources` — operation declaration, IRI-only relations.
- `gerard:api-platform-state-providers` — read pipeline counterpart.
- `gerard:api-platform-dto-resources` — Input DTOs consumed by Processors.
- `gerard:api-platform-resilience` — Circuit Breaker and async write patterns.
- `gerard:symfony-messenger` — bus configuration, middleware, transports.
- `gerard:messenger-retry-failures` — retry strategies and dead-letter queues.
- `gerard:cqrs-and-handlers` — Command/Query separation with Messenger.
- `gerard:doctrine-transactions` — flush strategies and optimistic locking.
