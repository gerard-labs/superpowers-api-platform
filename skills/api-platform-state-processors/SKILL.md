---
name: api-platform-state-processors
description: Write or evolve an API Platform 4.3 State Processor — turn a DTO Input into a persistence effect (Doctrine + dispatch). Covers the Autowire-based decoration of `api_platform.doctrine.orm.state.persist_processor` / `remove_processor`, the `DeleteOperationInterface` discriminator, the native Messenger modes (`messenger: 'input'`, `messenger: true`, HTTP 202 / `output: false`), and the CQRS command-bus delegation pattern. Trigger when wiring `Post` / `Put` / `Patch` / `Delete` with custom logic, when bridging API Platform to Messenger, or when persistence must trigger an asynchronous side effect.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — State Processors

## Use when
- A `Post` / `Put` / `Patch` / `Delete` operation needs custom write logic (transformation, dispatching, side effect).
- You want to decorate the Doctrine persist / remove processor while keeping the default behavior.
- The write must be **asynchronous** (long ERP call, PDF generation) — use the native Messenger mode.
- You apply CQRS and want to dispatch a Command to a bus instead of persisting directly.

## Default workflow
1. Scaffold with `php bin/console make:state-processor`.
2. Inject `api_platform.doctrine.orm.state.persist_processor` (and `remove_processor` when relevant) via `#[Autowire(service: ...)]`.
3. Discriminate `Delete` with `$operation instanceof DeleteOperationInterface` if a single Processor covers all writes.
4. For async-only operations, prefer the native `messenger: 'input'` mode + `status: 202` over a custom Processor.
5. Wire on the operation: `new Post(processor: MyProcessor::class)`.

## Guardrails
- No business logic in the Processor — orchestrate a service or a CQRS handler.
- Wrap multi-entity writes in a transaction (`wrapInTransaction` or `doctrine_transaction` middleware).
- POST returns the persisted entity / DTO (API Platform emits 201 + Location).
- DELETE returns `null` (API Platform emits 204).
- If you want **Doctrine persist + async dispatch**, decorate `persist_processor`. Do **not** use `messenger: true`, which bypasses Doctrine entirely.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full Autowire decoration recipe, the native Messenger modes, the CQRS pattern, the `DeleteOperationInterface` discriminator, and the 202 / `output: false` semantics.

## Output contract
- A new Processor class in `src/State/` wired on the operation.
- Transactional integrity guaranteed for multi-entity writes.
- Functional tests for the happy path + 422 + 403 + idempotency / retry where async is involved.

## References
- `reference.md`
