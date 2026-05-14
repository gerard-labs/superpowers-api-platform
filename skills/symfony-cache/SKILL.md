---

name: symfony-cache
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Use Symfony Cache pools (PSR-6 / PSR-16) — Redis / Memcached / APCu / filesystem adapters, cache tags for selective invalidation, HTTP cache (`cacheHeaders`, `cacheTags`) and Varnish PURGE integration, APCu pool for API Platform metadata in prod, chain adapters (fast local + shared persistent), TTL tuning, cache warmers. Trigger on "cache an expensive query", "invalidate on write", "API Platform slow boot", or "Varnish purge".
---

# Symfony Cache (Symfony)

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
