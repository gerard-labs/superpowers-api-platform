---
name: anti-patterns-audit
description: >
  Standalone audit of the current diff (or a target file glob) against API
  Platform 4.3 + Symfony 7.4+ anti-patterns. Returns a Y/N checklist with
  evidence (file:line) for each hit. Invocable directly from gerard-gatekeeper
  or api-implementer self-audit; also usable hors-pipeline by a dev who wants a
  quick lint before opening a PR. Cross-cutting tool — not tied to a single
  API Platform surface.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
effort:
  low: Run the 7 high-signal regex set (mirror post-tool-use.sh). Output one line per hit.
  high: Full 24-rule checklist (16 AP 4.3 + 8 Symfony 7.4+) with Y/N + evidence per item.
  xhigh: Above + cross-check against project's `.claude/skills/*` overrides + AppSec rules.
---

# Anti-patterns audit

> Standalone version of the ex-`/self-audit-api` command (v0.1). Becomes a skill in v1.0 so any caller (Skill tool, gatekeeper, implementer self-audit, ad-hoc dev review) can invoke it without going through the full pipeline.

## Use when

- The gatekeeper agent wants a structured pass before composing its VERDICT.
- The implementer wants to confirm the diff is clean before declaring "Definition of Done".
- A dev runs it directly via `Skill gerard:anti-patterns-audit` against the staged diff.

## Inputs

One of:
- `target: diff` — audit `git diff --cached` (default if nothing specified)
- `target: branch` — audit `git diff main...HEAD`
- `target: <glob>` — audit files matching the glob (e.g. `src/**/*.php`)

## Guardrails

- This skill is read-only — it never modifies files, runs `git commit`, or writes outside the Task return value.
- It runs against the surface specified by `target`. Never expand silently (e.g. don't audit the whole repo when asked for the diff).
- If the surface is empty (no `*.php` changes), return an empty report rather than scanning unrelated files.
- The 24 base rules are the canonical list. Do not invent new ones at runtime — if a new pattern is needed, propose adding it to this SKILL.md or to `.claude/skills/<project>/anti-patterns-audit/SKILL.md`.

## Default workflow

### Step 1 — Collect the surface

```bash
# default: staged diff
git diff --cached --name-only --diff-filter=AM | grep -E '\.php$'

# or: branch
git diff main...HEAD --name-only --diff-filter=AM | grep -E '\.php$'

# or: glob
ls -1 <glob>
```

### Step 2 — Run the 7 high-signal regex pass

Same patterns as `hooks/post-tool-use.sh` — these are the **fast-feedback** rules. If any match, flag and continue.

| # | Pattern | Why |
|---|---|---|
| 1 | `\b(dd\|dump\|var_dump\|var_export\|print_r)\s*\(` | Debug residue in committed code |
| 2 | `//\s*(TODO\|FIXME\|XXX)` | Half-finished work — Symfony 7.4+ rule |
| 3 | `:\s*mixed\b` (return type) | `mixed` in public signature — Symfony 7.4+ rule |
| 4 | `@ApiPlatform\\` | Legacy 3.x annotation |
| 5 | `operations:\s*\[\s*new\s+Get\(\)\s*,\s*new\s+GetCollection\(\)\s*\]` | Manual default ops — AP 4.3 anti-pattern |
| 6 | `(localhost\|127\.0\.0\.1)` (in non-test code) | Hard-coded URL |
| 7 | Repository class extending Doctrine AND containing `#[ApiResource]` | Coupling repo to resource |

### Step 3 — Run the 24-rule structured checklist

Recopy this checklist and fill Y/N per item. For each "Y" hit, give the file:line of the first match.

**API Platform 4.3 anti-patterns (16)**:

- [Y/N] `#[ApiFilter(...)]` used (banned — use `parameters: [new QueryParameter(filter: ...)]`)
- [Y/N] Class `extends AbstractFilter` (banned — use `implements FilterInterface` + `BackwardCompatibleFilterDescriptionTrait`)
- [Y/N] `openapiContext: [...]` used (banned — use `openapi: new Model\Operation(...)`)
- [Y/N] `'hydra:member'`, `'hydra:totalItems'`, `'hydra:view'`, `'hydra:next'` referenced in tests (banned — 4.x default `hydra_prefix: false` so use `'member'`, `'totalItems'`, etc.)
- [Y/N] `ApiPlatform\Core\` imports anywhere (banned — use `ApiPlatform\`)
- [Y/N] `SerializerAwareProviderInterface` or `SerializableProvider` referenced (banned — deprecated 4.2, removed v5)
- [Y/N] DTO field is a scalar ID (`int $customerId`) where it should be the IRI of the related resource (`Customer $customer`)
- [Y/N] `EntityManagerInterface` injected into a State Provider (banned — inject repository or service)
- [Y/N] Filter declared without explicit `property:` (4.3 requires it)
- [Y/N] Circular relation without `#[MaxDepth(n)]`
- [Y/N] Free `string` for status (banned — use `BackedEnum`)
- [Y/N] Auto-increment `int` ID exposed on a public resource (banned — use UUID v7 / ULID)
- [Y/N] `event_listeners_backward_compatibility_layer: true` or `keep_legacy_inflector: true` in config (3.x legacy)
- [Y/N] Test asserts default page size = 20 (banned — 4.x default is 30)
- [Y/N] `force_eager: true` on an entity with many relations (flip to `false`, add targeted join fetches)
- [Y/N] MCP tool exposed without rate-limit + audit log

**Symfony 7.4+ anti-patterns (8)**:

- [Y/N] `// TODO`, `// FIXME`, `// XXX` or wholesale-commented code blocks
- [Y/N] `@phpstan-ignore` / `@psalm-suppress` without a `// reason:` line citing framework/vendor constraint
- [Y/N] `mixed` in a public signature
- [Y/N] Reference to Symfony 6.4, 7.0, 7.1, 7.2 or 7.3 as a supported version (plugin targets 7.4+ LTS)
- [Y/N] JWT stored in `localStorage` (XSS leak — use HttpOnly cookie or in-memory)
- [Y/N] CORS configured with `allow_origin: ['*']` AND `allow_credentials: true`
- [Y/N] Hard-coded password or API key literal in committed code
- [Y/N] `$id` accepted from request without an authorization check on the actor

### Step 4 — Cross-check project overrides (xhigh only)

If `effort == xhigh`, also check `.claude/skills/*/anti-patterns-audit/SKILL.md` for a project-specific extension and apply its additional rules.

### Step 5 — Output

Markdown report :

```markdown
## Anti-patterns audit — <target>

### Fast-feedback pass (7 rules)
- ✅ All clean
OR
- ❌ Rule 4 (legacy 3.x annotation) — src/ApiResource/Foo.php:12

### Structured checklist (24 rules)
[Y/N list pasted, with file:line evidence on each Y]

### Summary
- Total findings: <n>
- Severity breakdown: H<n> / M<n> / L<n>
- Recommendation: <approve / fix-first / escalate>
```

## Output contract

The skill returns the markdown report directly to the caller. No state-file write, no marker protocol — caller reads from the Task return / Skill response.

## References

- `hooks/post-tool-use.sh` — same 7 fast-feedback regexes (source of truth)
- `agents/gerard-gatekeeper/agent.md` — invokes this skill during its review
- `agents/api-implementer/agent.md` — invokes for self-audit (step 5 of its workflow)
- `docs/anti-patterns.md` — canonical doctrine doc (session 6)
