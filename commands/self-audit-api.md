---
description: Self-audit — copies the API Platform 4.3 anti-patterns checklist and fills Y/N for the current diff (`git diff`)
allowed-tools: Read, Bash, Grep, Glob
---

# /self-audit-api

Self-audit the current diff against the API Platform 4.3 + Symfony 7.4+ anti-patterns checklist.

## Step 1 — Read the canonical checklist

```
Read docs/symfony/api-platform-anti-patterns.md
```

## Step 2 — Identify changed files

```
git diff --name-only
git diff --stat
```

## Step 3 — For each anti-pattern category, inspect the diff

| Category | Checks |
|---|---|
| Filters & queries | `#[ApiFilter]` / `extends AbstractFilter` / legacy filter classes / filter without explicit `property:` |
| Operations & serialization | `openapiContext:` / `'hydra:*'` in tests / scalar ID in payload / free `string` for status / missing `MaxDepth` / auto-increment public ID |
| Namespaces & deprecated | `ApiPlatform\Core\…` / `SerializerAwareProviderInterface` / `SerializableProvider` / `event_listeners_backward_compatibility_layer` / `keep_legacy_inflector` |
| Performance & security | `force_eager: true` unjustified / MCP without rate limit / CORS `*` with credentials |
| Symfony 7.4+ | `// TODO` / `// FIXME` / `@phpstan-ignore` without reason / `mixed` in public signature / Symfony 6.x referenced |
| Tests | Test default page 20 / `'hydra:*'` assertion / implementation-style names |

## Step 4 — Emit a Y/N checklist

For each item, answer:

- `Y` — pattern absent from the diff (good)
- `N` — pattern present in the diff (flag, with file:line)
- `N/A` — pattern not applicable to this diff type

## Step 5 — Output format

```
# API Platform 4.3 Self-Audit — <date>

Diff: <N> files, +<X>/-<Y> lines

## Anti-patterns checklist

| # | Item | Status | Details |
|---|---|---|---|
| 1 | No #[ApiFilter] | Y / N / N/A | <file:line if N> |
| 2 | No extends AbstractFilter | Y / N / N/A | ... |
| ... | ... | ... | ... |

## Summary
- Y: <N>/24
- N: <N>/24 — addressable before merge
- N/A: <N>/24 — skip (out of scope)

## Action items (N items only)
1. <file:line> — <rule> — <recommended fix>
```

## When to run

- Before manually committing a non-pipelined change
- After a `/dev` to double-check the implementer's self-audit
- In a CI step on every PR (optional — the lint script does this systematically)

## Skip in pipeline mode

When running `/api-resource-pipeline` or `/api-resource-ship`, the `api-platform-implementer` already emits a Y/N self-audit, and `symfony-reviewer` enforces the same checklist. This command is for **standalone** manual audits.
