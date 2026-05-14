---

name: messenger-retry-failures
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Configure Symfony Messenger retry strategies and dead-letter queue handling — `retry_strategy` (max_retries, delay, multiplier, max_delay) per transport, `failure_transport`, `messenger:failed:show` / `retry` / `remove` CLI, idempotency via correlation IDs, exponential backoff, circuit-breaker handler pattern, audit log on terminal failures. Trigger when a message keeps re-queueing, when DLQ grows, when designing async write semantics for an unreliable upstream.
---

# Messenger Retry Failures (Symfony)

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
