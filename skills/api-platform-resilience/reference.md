# API Platform 4.3 — Resilience (reference)

An API that depends on a third-party service (ERP, supplier, secondary database) must keep working — even degraded — when that service goes down.

## 1. Circuit Breaker (Closed → Open → Half-Open)

Three states:

- **Closed** — normal traffic. After N consecutive failures, the circuit opens.
- **Open** — every request fails immediately (fail-fast), no upstream call. After a timeout, switches to Half-Open.
- **Half-Open** — a handful of test requests. If they succeed, close the circuit; otherwise reopen.

### Typical usage in a service that calls the ERP

```php
final class ErpQuoteService
{
    public function __construct(
        private CircuitBreaker $circuitBreaker,
        private ErpClient $erpClient,
        private QuoteCache $cache,
    ) {}

    public function getQuote(string $id): ?array
    {
        if ($this->circuitBreaker->isOpen()) {
            return $this->cache->get($id);  // fallback
        }
        try {
            $quote = $this->erpClient->getQuote($id);
            $this->circuitBreaker->recordSuccess();
            $this->cache->put($id, $quote);
            return $quote;
        } catch (ErpException $e) {
            $this->circuitBreaker->recordFailure();
            return $this->cache->get($id);  // fallback
        }
    }
}
```

Several PHP libraries provide a Circuit Breaker primitive (`ackintosh/ganesha`, `prestashop/circuit-breaker`, in-house implementations). Pick one or build a thin wrapper around Symfony Cache for the state store.

---

## 2. Degraded mode in the JSON response

When the cached fallback is served, **tell the client**:

```json
{
  "id":     "Q-12345",
  "amount": 15420.50,
  "_notice": {
    "type":    "degraded_mode",
    "message": "Data may be stale. Real-time quote is temporarily unavailable."
  },
  "_cached_at": "2026-05-11T09:15:00Z"
}
```

This keeps user trust intact without masking the incident. The frontend can show a banner ("Real-time data unavailable, showing cached values").

---

## 3. Async writes for slow dependencies

When a critical write (placing an order in an ERP) depends on a slow third-party, **decouple the user confirmation from the upstream execution**.

### Flow

1. The API Platform Processor persists the entity in status `draft` or `pending_erp_processing`.
2. It dispatches a Messenger command (`PlaceOrderInErp`) on an async transport.
3. The user receives an immediate 201 + confirmation ("your order has been received").
4. A worker consumes the queue and calls the ERP in the background.
5. The status transitions to `processed` or `failed`.

### Processor — minimal pattern

```php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\Messenger\MessageBusInterface;

final readonly class CreateOrderProcessor implements ProcessorInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private ProcessorInterface $persist,
        private MessageBusInterface $bus,
    ) {}

    public function process(mixed $data, Operation $op, array $uriVars = [], array $ctx = []): mixed
    {
        $order = $this->persist->process($data, $op, $uriVars, $ctx);
        $this->bus->dispatch(new PlaceOrderInErp($order->getId()));
        return $order;
    }
}
```

### Operation declaration

```php
new Post(
    processor: CreateOrderProcessor::class,
    status:    202,                       // 202 Accepted (in progress)
)
```

(If the response body is still needed — confirmation, IRI — keep the default `output:` and 201; use 202 + `output: false` only for purely fire-and-forget operations.)

---

## 4. Retry strategy — exponential backoff

```yaml
framework:
    messenger:
        transports:
            async_erp:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                retry_strategy:
                    max_retries: 5
                    delay:       1000        # 1s
                    multiplier:  2           # ×2 per retry
                    max_delay:   60000       # 60s cap
                failure_transport: failed
            failed:
                dsn: 'doctrine://default?queue_name=failed'
```

---

## 5. Failure transport

```bash
php bin/console messenger:failed:show
php bin/console messenger:failed:retry 1234
php bin/console messenger:failed:remove 1234
```

Use the `failed` transport to inspect persistent failures. **Never blindly `messenger:failed:retry`** — investigate the root cause first.

Cf. `gerard:messenger-retry-failures` for the deeper pattern.

---

## 6. Lifecycle via Symfony Workflow

Model the cycle: `draft → pending_erp_processing → processed | failed`.

```yaml
framework:
    workflows:
        order:
            type: state_machine
            marking_store:
                type: method
                property: status
            supports:
                - App\Entity\Order
            initial_marking: draft
            places:
                - draft
                - pending_erp_processing
                - processed
                - failed
            transitions:
                submit:
                    from: draft
                    to:   pending_erp_processing
                processed:
                    from: pending_erp_processing
                    to:   processed
                fail:
                    from: pending_erp_processing
                    to:   failed
                retry:
                    from: failed
                    to:   pending_erp_processing
```

Expose the current status via the API:

```http
GET /api/orders/123
{
  "status":            "pending_erp_processing",
  "erp_sync_attempts": 2
}
```

The client polls or subscribes (Mercure) to know when the status flips.

---

## 7. Test strategy

- Wire the Circuit Breaker with an in-memory state store in tests.
- Force the Open state and assert the response contains the `_notice` marker.
- Run the worker in dispatch-sync mode for integration tests:

  ```bash
  php bin/console messenger:consume async_erp --limit=1 --time-limit=10
  ```

- Assert the workflow transitions explicitly in functional tests.

---

## 8. Operational checklist

- ☐ Every external HTTP call has a timeout.
- ☐ Every external HTTP call is wrapped in a Circuit Breaker.
- ☐ Every async transport has a retry strategy with a cap.
- ☐ The failure transport is monitored (alert on growth).
- ☐ The DLQ has a manual review path (operator can inspect / retry / abandon).
- ☐ The frontend recognizes degraded-mode responses.
- ☐ Idempotency keys are passed on external calls where retries can happen.

---

## 9. Related skills

- `gerard:symfony-messenger` — bus, transports, middleware.
- `gerard:messenger-retry-failures` — retry strategies + DLQ deep dive.
- `gerard:api-platform-state-processors` — Processor patterns + native Messenger modes.
- `gerard:rate-limiting` — additional protection on write endpoints.
- `gerard:api-platform-errors` — surfacing degraded-mode and failures via RFC 7807.
