---
name: goal-patterns
description: >
  Catalog of `/goal` condition templates used by `/api`. One base condition
  + 5 shape-specific addenda (new-resource, new-operation, new-filter,
  new-state-flow, migration). The `/api` command reads these templates at
  step 4 to compose the final goal condition. Wiring skill (consumed by a
  command, not by an agent's per-surface doctrine).
allowed-tools:
  - Read
effort:
  low: Base condition only (4 bullets) + shape addendum matching story.
  high: Full base condition + all 5 addenda (so the caller can switch shapes mid-flow).
  xhigh: Above + commented rationale per bullet (why APPROVE-must, why AppSec H1/H2 zero, etc.).
---

# /goal condition templates

> Source of truth for the `/goal` conditions that drive `/api`. Until v0.1, these were hardcoded inside `commands/api.md` (step 4). In v1.0 they live here so the command stays thin and templates can be reused (e.g. an external dev script that wraps `/api` can read the same set).

## Use when

- `commands/api.md` step 4 needs to compose the `/goal` condition based on the detected story shape.
- An external wrapper script wants to reuse the same `/goal` semantics outside the `/api` flow.
- A contributor edits this catalog to add a new shape.

## Guardrails

- The 4 base bullets (`gerard-gatekeeper APPROVE` / `AppSec H1+H2 resolved` / `tests pass` / `no recent anti-pattern flags`) are non-negotiable. Every shape inherits them — never drop or weaken a base bullet for a specific story.
- Hard cap is 12 turns on the `/goal` invocation itself (decision verrouillée — section 1 row 7). Don't render conditions that imply more turns.
- Avoid hedge words in rendered text ("ideally", "if possible", "best effort") — the Haiku evaluator reads verbatim and a softened bullet weakens the gate.
- Substitute `<plural>` and `<branch>` placeholders before passing to `/goal`. The caller (`commands/api.md` step 4) has both values in scope.

## Default workflow

1. Read this SKILL.md.
2. Determine the story shape from the user's `/api` argument (the caller does this in step 3 of `commands/api.md`).
3. Compose the final condition string : base 4 bullets + the addendum matching the shape, with placeholders substituted.
4. Hand the string to the native `/goal` primitive.

## Output contract

The skill response is the rendered condition string — base 4 bullets concatenated with the matching shape addendum (bullet 5), placeholders resolved. The caller passes it directly to `/goal`. No state file, no marker protocol.

## Base condition (always appended)

```
Goal cleared when:
  1. gerard-gatekeeper returned VERDICT=APPROVE on its last review
  2. AppSec bilan in the latest gatekeeper report has no H1/H2 findings open
  3. all listed test commands pass (status 0 from the session-start runner)
  4. no anti-patterns flagged by post-tool-use hook in the last 3 tool calls
```

The base 4 bullets are non-negotiable — every shape inherits them. Do NOT relitigate them per-story; they encode the v1.0 enforcement promise (gatekeeper APPROVE + AppSec resolved + tests green + hook-clean).

## Shape addenda

Pick exactly one based on the story shape detected at `/api` step 3. Append as bullet `5`.

### `new-resource`

```
  5. The new resource is reachable via `GET /api/<plural>` and has at least one functional test.
```

### `new-operation`

```
  5. The new operation has a functional test and is documented in OpenAPI.
```

### `new-filter`

```
  5. The filter is declared in the resource operations array (parameters: [QueryParameter])
     and has a functional test covering at least one positive + one negative case.
```

### `new-state-flow`

```
  5. State Processor/Provider is wired via `processor:` / `provider:` on the operation
     and unit-tested.
```

### `migration`

```
  5. Doctrine migration applies cleanly + has a down() that reverses it.
```

### `bugfix`

```
  5. A regression test reproduces the bug pre-fix and passes post-fix.
```

### `refactor`

```
  5. Public API surface unchanged; existing tests still pass; no new responsibilities introduced.
```

### `security-hardening`

```
  5. AppSec bilan contains an explicit row for the hardening with status=resolved + reproduction.
```

### `generic`

No addendum — the base 4 bullets are the whole condition.

## Composition rules

1. **Substitute `<plural>` / `<branch>`** in addenda before passing to `/goal`. `/api` step 4 already has both values in scope.
2. **Cap at 12 turns** is set on the `/goal` invocation itself (decision verrouillée — section 1 row 7).
3. **The Haiku evaluator** reads the rendered condition verbatim — keep the language unambiguous. Avoid hedge words ("ideally", "if possible") that lower the gate.

## Consumed by

- `commands/api.md` step 4 — picks the addendum and renders the full condition string.
- Future: external dev wrapper scripts that want to reuse the same gate semantics.

## References

- `commands/api.md` — caller
- `agents/gerard-gatekeeper/agent.md` — produces the `VERDICT=APPROVE` that satisfies bullet 1
- `hooks/post-tool-use.sh` — produces the "no anti-patterns flagged" signal for bullet 4
- `docs/goal-patterns.md` — narrative doc with rationale (session 6)
