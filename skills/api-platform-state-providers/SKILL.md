---
name: api-platform-state-providers
description: Write or evolve an API Platform 4.3 State Provider — transform a data source (Doctrine, external API, cache) into the API representation. Covers the modern Autowire-based decoration of `api_platform.doctrine.orm.state.item_provider` / `collection_provider`, the `CollectionOperationInterface` discriminator, header-versioned providers, and the deprecated interfaces to remove (`SerializerAwareProviderInterface`, `SerializableProvider`). Trigger when adding a Provider to `Get` / `GetCollection`, decorating the Doctrine read pipeline, or shaping an Output DTO at read time.
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
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-state-providers/) + edge cases.
---

# API Platform 4.3 — State Providers

## Use when
- A `Get` / `GetCollection` operation needs a transformation between the data source and the API representation.
- You want to decorate the Doctrine read pipeline (e.g. to add audit logging or shape an Output DTO).
- A response payload depends on a request header (versioning, locale).
- A Resource is backed by a non-Doctrine source (external API, in-memory store, search engine).

## Default workflow
1. Scaffold with `php bin/console make:state-provider`.
2. Inject the Doctrine item / collection providers via `#[Autowire(service: '…')]` (modern decoration pattern).
3. Discriminate collection vs item with `$operation instanceof CollectionOperationInterface`.
4. Return `null` for missing items (API Platform emits a 404 automatically).
5. Wire on the operation: `new Get(provider: MyProvider::class)`.

## Guardrails
- Inject a repository or a service, **never** `EntityManagerInterface` directly inside a Provider.
- Do **not** code role checks inside the Provider — use `security:` on the operation or a voter.
- Do **not** persist from a Provider; that is the Processor's job.
- Remove any `SerializerAwareProviderInterface` / `SerializableProvider` implementation — those interfaces are deprecated since 4.2 and gone in 5.0.

## Progressive disclosure
- `SKILL.md` covers the basic pattern and rules.
- `reference.md` carries the full decoration recipe, the collection-vs-item discriminator, a header-versioned example, and an N+1-avoidance reminder.

## Output contract
- A new Provider class in `src/State/` wired on the operation.
- Functional tests covering the happy path **and** the null/404 case.
- No legacy interfaces remaining; no hardcoded security inside the Provider.

## References
- `reference.md`
