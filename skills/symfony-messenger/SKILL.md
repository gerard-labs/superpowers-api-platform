---
name: symfony-messenger
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Implement Symfony Messenger — sync vs async transports (Doctrine, Redis, RabbitMQ, AMQP, SQS), `#[AsMessageHandler]` per command/query, middleware (`doctrine_transaction`, `doctrine_close_connection`, `validation`, custom), bus per intent (`command.bus`, `query.bus`, `event.bus`), `MessageBusInterface` DI, envelope stamps, routing rules. API Platform 4.x natively supports `messenger: 'input'` on operations (HTTP 202 + async dispatch). Trigger on "async this write", "split command vs query", or "background worker".
---

# Symfony Messenger (Symfony)

## Use when
- Implementing asynchronous workflows with Messenger/Scheduler/Cache.
- Stabilizing retries and failure transports.

## Default workflow
1. Define async contract and delivery semantics.
2. Implement idempotent handlers and routing strategy.
2. Configure retries, failure transport, and observability.
2. Validate success/failure replay scenarios.

## Guardrails
- Assume at-least-once delivery, not exactly-once.
- Keep handlers deterministic and side-effect aware.
- Surface poison-message handling strategy.

## Progressive disclosure
- Use this file for execution posture and risk controls.
- Open references when deep implementation details are needed.

## Output contract
- Async config/handlers updated.
- Retry/failure policy decisions.
- Operational validation evidence.

## References
- `reference.md`
- `docs/complexity-tiers.md`
