# Hooks

> Five deterministic hooks bracket every `/api` run. The hooks are written in pure bash and shipped under `hooks/`. They are declared in `hooks/hooks.json` and registered by Claude Code at session start.

## Index

| Event | Hook script | Matcher | Section |
|---|---|---|---|
| `SessionStart` | `session-start.sh` | `startup\|resume\|clear\|compact` | [↓](#session-start) |
| `UserPromptSubmit` | `user-prompt-submit.sh` | — | [↓](#user-prompt-submit) |
| `PreToolUse` | `pre-tool-use.sh` | `Write\|Edit\|MultiEdit` | [↓](#pre-tool-use) |
| `PostToolUse` | `post-tool-use.sh` | `Write\|Edit\|MultiEdit` | [↓](#post-tool-use) |
| `Stop` | `stop.sh` | — | [↓](#stop) |

All five exit `0` silently in the no-op path (so they never block legitimate work). Only the secret-block and the regex/phpstan failures use `decision: block` or `permissionDecision: deny`.

---

## Session start

**Script** : `hooks/session-start.sh` (≈ 700 lines bash — the heaviest hook).

**Triggers on** : `startup`, `resume`, `clear`, `compact`. Fires once per session boot, plus on every `/clear` or `/compact`.

**Job** :

1. Detect Symfony apps via `composer.json` containing `symfony/framework-bundle`. Supports monorepos where Symfony lives in a sub-dir.
2. Detect the **orchestration root** by walking up from the active app : the dir owning `Makefile`, `Makefile-solution`, `compose.yaml`, or `.ddev/`. Stops at `.git/`.
3. Detect the runner type with this priority order :
   1. **DDEV** if `.ddev/` is present
   2. **Make** if a canonical `Makefile` is present with at least one of `console` / `tests` / `ci` targets. Also detects the `Makefile` (boilerplate) vs `Makefile-solution` (project-owned) split.
   3. **FrankenPHP / Symfony Docker** if `compose.yaml` mentions `frankenphp` / `dunglas/symfony-docker` / `caddy`, or a `Caddyfile` / `frankenphp/` dir is present
   4. **Generic Compose** for any other `compose.*` file
   5. **Host** fallback
4. Detect the API Platform version (4.x split `api-platform/symfony` + `api-platform/doctrine-orm` ; legacy `api-platform/core`). Warn explicitly if `< 4.3` and point to `gerard:api-platform-upgrade`.
5. Detect the Symfony version. Warn if `< 7.4 LTS`.
6. Detect the test framework (Pest vs PHPUnit) from `composer.lock`.
7. Detect Make targets (`make help` parse) and surface them under `commands.*`.
8. Check Claude Code version `≥ 2.1.139`. Warn if older — `/goal` / `Monitor` / worktree isolation primitives are needed.

**Output** : JSON written to stdout. The Claude Code session reads it and surfaces the fields below to agents (via the system reminder area).

**Surfaced fields** (used by `api-implementer` and `gerard-gatekeeper`) :

```jsonc
{
  "runner_type": "make",           // ddev | make | symfony-docker | docker-compose | host
  "active_app": "<path>",          // dir containing the relevant composer.json
  "orchestration_root": "<path>",  // dir containing Makefile / compose / .ddev
  "test_framework": "pest",        // pest | phpunit
  "api_platform_version": "4.3.0",
  "symfony_version": "7.4.0",
  "commands": {
    "console": "make console",
    "test":    "make tests",
    "ci":      "make ci",
    "quality": "make quality",
    "migrations": "make migrations"
  },
  "makefile": {
    "primary_file": "/path/Makefile",
    "solution_file": "/path/Makefile-solution",     // null if no split
    "targets": ["help", "ci", "tests", "quality", "migrations", ...]
  }
}
```

**Example warning** (when Claude Code is too old) :

```text
gerard session-start: Claude Code 2.1.137 detected. v1.0 needs ≥ 2.1.139
                      for native /goal + Monitor + worktree isolation.
                      Consider upgrading: claude update.
```

**Override** : if you want to disable the session-start hook for a single session, set `--disable-all-hooks` on the Claude Code CLI. Note that without it the implementer falls back to generic commands (`./vendor/bin/phpunit`) instead of project-canonical ones (`make tests`).

---

## User prompt submit

**Script** : `hooks/user-prompt-submit.sh` (≈ 125 lines bash).

**Triggers on** : every prompt the user submits (no matcher — narrowed inside the script).

**Job** :

1. Read the prompt from stdin (`{ "prompt": "...", ... }` JSON payload).
2. If the prompt does **not** start with `/api` (with optional leading whitespace), exit silently. The hook only fires for `/api`, `/api-finalize`, `/api-doctrine`.
3. Lower-case the prompt and match against a keyword → skill mapping table (~30 patterns).
4. Emit an `additionalContext` system reminder listing the relevant `gerard:*` skills :

```text
Hook hint — prompt keywords suggest these gerard skills are likely relevant for this /api run.
Read their SKILL.md before dispatching workers if applicable:
- gerard:api-platform-filters
- gerard:api-platform-pagination
```

**Example input** :

```text
/api "Add a Product resource with name, price, BackedEnum status and filter by status"
```

**Example output** (additionalContext injected before Claude reads the prompt) :

```text
- gerard:api-platform-filters
- gerard:api-platform-resources
- gerard:api-platform-serialization
```

**Keyword → skill map (excerpts)** :

| Keyword pattern | Skill |
|---|---|
| `filter\|search\|sort\|order` | `api-platform-filters` |
| `paginat\|page size\|cursor` | `api-platform-pagination` |
| `mcp\|model context protocol` | `api-platform-mcp` |
| `upload\|multipart\|file storage\|attachment` | `api-platform-file-upload` |
| `security\|jwt\|oidc\|cors\|voter\|auth` | `api-platform-security` |
| `dto` | `api-platform-dto-resources` |
| `migration\|doctrine-migrations` | `doctrine-migrations` |
| `messenger\|async` | `symfony-messenger` |
| (~25 more) | (see `hooks/user-prompt-submit.sh`) |

**Override** : edit `hooks/user-prompt-submit.sh` directly to add or remove patterns. The file is reloaded next time the hook fires (no daemon restart).

---

## Pre tool use

**Script** : `hooks/pre-tool-use.sh` (≈ 45 lines bash).

**Triggers on** : `Write` / `Edit` / `MultiEdit` (matcher in `hooks.json`).

**Job** : block writes to filenames matching a secret pattern. Narrow by design — false positives erode trust in the hook.

**Blocked basename patterns** :

```
.env, .env.*, *.pem, *.key, *.p12, *.pfx, *credentials*, *.crt,
id_rsa, id_ed25519, id_ecdsa, *.kdbx
```

**Example block** (output written as JSON, Claude Code denies the tool call) :

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "gerard pre-tool-use blocked write to /repo/.env.local: filename matches a secret pattern (.env*, *.pem, *.key, *.p12, *.pfx, *credentials*, *.crt, ssh keys, *.kdbx). If you truly need to edit this, ask the user to do it manually."
  }
}
```

**Override** : if you legitimately need to edit a blocked file path, ask the user to do it manually outside Claude. The hook does **not** support an env-var bypass — making the bypass easy would defeat the purpose.

---

## Post tool use

**Script** : `hooks/post-tool-use.sh` (≈ 150 lines bash).

**Triggers on** : `Write` / `Edit` / `MultiEdit` (matcher in `hooks.json`).

**Job** : on `*.php` writes, run a fast regex pass and (best-effort) phpstan, block with reason if any anti-pattern hits.

### The 7-regex fast pass

| # | Pattern | Why |
|---|---|---|
| 1 | `\b(dd\|dump\|var_dump\|var_export\|print_r)\s*\(` | Debug residue in committed code |
| 2 | `//\s*(TODO\|FIXME\|XXX)` | Half-finished work — Symfony 7.4+ rule |
| 3 | `:\s*mixed\b` | `mixed` in public signature — Symfony 7.4+ rule |
| 4 | `@ApiPlatform\\` | Legacy 3.x annotation |
| 5 | `operations:\s*\[\s*new Get\(\)\s*,\s*new GetCollection\(\)\s*\]` | Manual default ops — AP 4.3 anti-pattern |
| 6 | `https?://(localhost\|127\.0\.0\.1)` (non-test code) | Hard-coded URL — move to env |
| 7 | (reserved — extend in your fork if needed) | — |

If any pattern hits, the hook emits :

```json
{
  "decision": "block",
  "reason": "gerard post-tool-use regex scan found anti-patterns in src/ApiResource/Product.php:\n  - debug call must not ship — src/ApiResource/Product.php:42 — dd($x);\n\nFix these before continuing. The gatekeeper will block on these rules anyway — better to catch them now."
}
```

### PHPStan (best-effort, 30s timeout)

After the regex pass passes, the hook walks up from the file to find a phpstan binary :

1. `vendor/bin/phpstan` (host or container-mounted)
2. `.ddev/` ancestor → `ddev exec phpstan analyse ...`
3. Otherwise skip silently — phpstan is best-effort, the gatekeeper does the full pass

Timeout : `timeout 30s`. Exit 124 (ran out) → soft-skip.

If phpstan exits non-zero with real output : `{ "decision": "block", "reason": "phpstan flagged ...:\n<output>\n\nFix before continuing." }`.

### Override

To disable the regex scan or phpstan portion for a session, edit `hooks/post-tool-use.sh` and either narrow the `scan_pattern` calls or replace `find_phpstan_runner` with `return 1`. The hook is intentionally simple bash — no env-var feature flag.

---

## Stop

**Script** : `hooks/stop.sh` (≈ 25 lines bash).

**Triggers on** : every Claude stop.

**Job** : minimal scope (decision #11 in [`v1.0-plan.md`](v1.0-plan.md) section 1). Emit a `terminalSequence` desktop notification :

```text
gerard: goal cleared on api/add-product-resource. Run /api-finalize to commit + PR.
```

The `terminalSequence` field (Claude Code 2.1.119+) emits a `BEL` (`\a`) + an ANSI OSC 9 (`\033]9;<msg>\a`) sequence — most terminals translate this into a desktop notification, dock bounce, or audible bell.

### Why so minimal

Anti-pattern scans live in the gatekeeper (subjective full review) and PostToolUse hook (objective inline regex). Duplicating them at Stop produces false positives when Claude pauses on legitimate work (e.g. editing `skills/api-platform-upgrade/` which intentionally documents legacy patterns). See [`how-it-works.md#why-the-stop-hook-is-minimal`](how-it-works.md#why-the-stop-hook-is-minimal).

---

## Hooks declaration

The hooks are wired via `hooks/hooks.json` :

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|resume|clear|compact",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh" }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/user-prompt-submit.sh" }]
    }],
    "PreToolUse": [{
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use.sh" }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.sh" }]
    }],
    "Stop": [{
      "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop.sh" }]
    }]
  }
}
```

`${CLAUDE_PLUGIN_ROOT}` is expanded by Claude Code to the absolute path of the installed plugin.

---

## Overriding hooks at the project level

Hooks ship inside the plugin and are not designed to be edited per-project. If you need project-specific behavior :

1. **Disable a hook** : set the project's `.claude/settings.local.json` to disable specific hooks (consult Claude Code docs for the exact key name).
2. **Add complementary hooks** : projects can declare additional hooks via their own `.claude/hooks/` setup. These run alongside the plugin's hooks (multiple hooks per event are supported).
3. **Disable all plugin hooks** : run with `--disable-all-hooks` for an emergency bypass. Note : you lose the enforcement promise, so this is for debugging, not normal work.

For more, see [`troubleshooting.md#hooks`](troubleshooting.md#hooks).

---

## References

- [`v1.0-plan.md`](v1.0-plan.md) section 3d — hook table
- [`v1.0-plan.md`](v1.0-plan.md) section 1, decision #11 — Stop hook scope rationale
- [`how-it-works.md`](how-it-works.md) — hooks in the pipeline sequence
- [`anti-patterns.md`](anti-patterns.md) — what PostToolUse blocks (mirror of the gatekeeper's fast-feedback subset)
