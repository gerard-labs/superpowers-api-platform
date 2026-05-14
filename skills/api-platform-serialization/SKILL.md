---
name: api-platform-serialization
description: Master API Platform 4.3 serialization — design groups (`entity:operation` convention, read ≠ write), force IRI on relations with `#[ApiProperty(readableLink: false, writableLink: false)]`, prevent circular references with `MaxDepth`, use `BackedEnum` natively, apply `#[Context]` for per-property formats, install a Context Builder for dynamic role-based groups, decide between Context Builder (runtime) and Resource/Operation Mutators (build-time), and configure 4.x defaults (`hydra_prefix: false`, `skip_null_values: true`, `gen_id`). Trigger when adding `Groups`, mixing read/write, deciding between embed vs IRI, calculating fields in a normalizer, hiding fields by role, or debugging "why is my field null in the response".
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
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-serialization/) + edge cases.
---

# API Platform 4.3 — Serialization

## Use when
- Adding `#[Groups]` to a resource or DTO.
- Forcing relations to serialize as IRIs (or, exceptionally, embedded).
- Calculating fields without polluting the entity (custom normalizer).
- Adding admin-only or owner-only fields with a dynamic group.
- Tuning per-property date format / context with `#[Context]`.

## Default workflow
1. Define the read vs write groups (`product:list`, `product:read`, `product:create`, `product:update`).
2. Apply `#[Groups]` on every exposed property with a deliberate scope.
3. Force IRI on relations with `#[ApiProperty(readableLink: false, writableLink: false)]` unless embedding is explicitly required.
4. Add `MaxDepth` + `enable_max_depth: true` on circular relations.
5. For computed / role-dependent fields, decide: Context Builder (runtime), Mutator (build-time), or custom Normalizer.

## Guardrails
- **One group per direction.** Never reuse `product:read` for writes.
- **Sensitive fields out of every group.** Use `#[Ignore]` for passwords, tokens, reset codes.
- **`BackedEnum` for statuses.** Never free `string`.
- **`hydra_prefix: false`** is the 4.x default — tests and clients consume `member`, `totalItems`, etc. without the `hydra:` prefix.
- **`skip_null_values: true`** is the 4.x default — no more `"field": null` in responses.

## Progressive disclosure
- `SKILL.md` covers posture and decision tree.
- `reference.md` carries the full patterns: groups, MaxDepth, IRI forcing, BackedEnum, `#[Context]`, custom Normalizer (ALREADY_CALLED pattern), conditional normalizer (Security-aware), Context Builder vs Mutator, `gen_id`, name converter, `getValues()` trick.

## Output contract
- Resource / DTO with explicit per-property groups.
- Relations either IRI-only or embedded with a documented reason.
- Tests asserting the exact shape of the JSON-LD response.
- No `null` properties leaking in the response (verify `skip_null_values`).

## References
- `reference.md`
