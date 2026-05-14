---
name: api-platform-resilience
description: Build resilience patterns around an API Platform 4.3 app — Circuit Breaker (Closed → Open → Half-Open) on external dependencies (ERP, payment, search), cached fallback on Open state with a `_notice.type: degraded_mode` marker in the response, asynchronous writes for slow upstreams (HTTP 202 + status: pending_erp_processing dispatched via Messenger with exponential-backoff retry + DLQ + Symfony Workflow lifecycle), and exposure of the current status through the API. Trigger when the API depends on a third-party service (ERP, CRM, payment gateway, mailer, search engine), on "circuit breaker", "degraded mode", "async write", "retry policy", "DLQ", or "what if the ERP is down".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
effort:
  low: SKILL.md only — "Use when" + default workflow + key bullets.
  high: SKILL.md + reference.md — full doctrine.
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-resilience/) + edge cases.
---

# API Platform 4.3 — Resilience

## Use when
- The API depends on a third-party service (ERP, CRM, payment, mailer, search).
- Writes are slow and should not block the user request.
- The third-party is intermittently unreliable.
- A degraded-mode response is preferable to a 5xx.

## Default workflow
1. Identify each external dependency. Decide its criticality (must succeed sync vs degraded fallback acceptable).
2. Wrap external calls in a **Circuit Breaker** with three states (Closed / Open / Half-Open).
3. On Open: serve a cached fallback **and** add `_notice.type: degraded_mode` to the response.
4. For slow writes: persist a `pending_*` status, dispatch a Messenger command, return HTTP 202.
5. Model the lifecycle with Symfony Workflow (`draft → pending_erp_processing → processed | failed`).
6. Configure exponential backoff retry + DLQ on the Messenger transport.

## Guardrails
- **No silent fallback.** Always surface degraded mode in the response so the client can decide.
- **Idempotency** on external calls — assume retries will happen.
- **Timeouts** on every HTTP / RPC call — never block indefinitely.
- **DLQ monitored.** Failures accumulating in `failed` must trigger an alert; don't `messenger:failed:retry` blindly.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full patterns: Circuit Breaker implementation (states, transitions, fallback cache), degraded-mode JSON shape, async write end-to-end (Processor, status, Messenger transport, retry strategy, failed transport, Workflow), exposing the status through the API.

## Output contract
- Each external dependency wrapped in a Circuit Breaker (and tested).
- Async writes return HTTP 202 with a queryable `status` field.
- Messenger retry strategy + DLQ configured per transport.
- Workflow definition (`draft → pending → processed | failed`) explicit.
- Tests cover the Open state (degraded fallback), the failure transport, and the recovery path.

## References
- `reference.md`
