---
name: api-platform-dto-resources
description: Introduce Input/Output DTOs in API Platform 4.3 to decouple the API contract from the Doctrine entity, validate at the boundary, force IRI-only relations (no scalar IDs), and use BackedEnum natively. Covers the new Symfony Object Mapper 4.3 integration (`#[Map]`, ObjectMapperProvider/Processor) for boilerplate-free DTO ↔ Entity mapping on simple CRUDs. Trigger when the API contract diverges from the entity, when validation rules differ per operation, when a price/money/enum needs explicit boundaries, or when "decouple my entity from the API".
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
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-dto-resources/) + edge cases.
---

# API Platform 4.3 — Input/Output DTOs (+ Object Mapper 4.3)

## Use when
- The API contract should not be a one-to-one reflection of the Doctrine entity.
- Validation rules differ per operation (`CreateOrderInput` vs `UpdateOrderInput`).
- The contract needs IRI-only relations and `BackedEnum` statuses.
- A simple CRUD could benefit from the new Symfony Object Mapper 4.3 to skip Provider/Processor boilerplate.

## Default workflow
1. Decide: pure DTO (full Provider/Processor) **or** Object Mapper 4.3 (when mapping is mechanical).
2. Define `Input` and `Output` DTOs as `final readonly` with Symfony validator attributes.
3. Wire them on the operation (`input:`, `output:`, `processor:` / `provider:`) — or annotate with `#[Map]` if using Object Mapper.
4. Test the contract: 201 with the right shape, 422 on invalid payload, IRI resolution.

## Guardrails
- DTOs hold no business logic — just validated transport.
- Always type relations as Resources (`Customer $customer`), never scalar IDs.
- Use `BackedEnum` for any status / type / category — never free `string`.
- Object Mapper 4.3 is for mechanical mapping only. Persistence logic, aggregation, side effects → keep an explicit Processor.

## Progressive disclosure
- `SKILL.md` lists the decision and the four steps.
- `reference.md` covers the full DTO patterns + Object Mapper 4.3 (`#[Map(source:)]`, transformers, when it auto-activates).

## Output contract
- New `final readonly` Input/Output classes.
- The `#[ApiResource]` operation wired with the right `input` / `output` / `processor` / `provider` (or `#[Map]` annotations).
- Validation + IRI-resolution coverage in functional tests.

## References
- `reference.md`
