# gerard v1.0 — E2E test report

**Date** : 2026-05-14
**Branch** : `v1.0`
**Tested commit (at report time)** : `89e0c81` (S7 fixture tweak)
**Tester** : Session 7 — static validation by Claude session + interactive Tests 1+4 by user

---

## Strategy

The 5 scenarios from `docs/v1.0-plan.md` § Session 7 are validated in two complementary ways :

- **Static / isolation** (in this Claude session, no `/api` interactive run) :
  hooks are tested by piping mock JSON payloads to their scripts, validators are run, manifests are parsed.
  This covers Tests 2 (anti-pattern catch), 3 (secret protection) and 5 (`/api-finalize` dry-run).
- **Interactive E2E** (user-side, in a separate `claude` session inside the fixture) :
  Tests 1 (happy path full pipeline) and 4 (memory accumulation across two runs) need the real `/api` to dispatch agents in parallel, exercise `/goal`, and let the implementer touch the memory directory.

Both tracks feed the verdict at the bottom.

---

## Pre-test : environment & manifests

| Check | Expected | Observed | ✅/❌ |
|---|---|---|---|
| `claude --version` | ≥ 2.1.139 | `2.1.141` | ✅ |
| `php -v` | ≥ 8.2 | `8.4.11` (NTS) | ✅ |
| `php -m \| grep pdo_sqlite` | present | present (installed mid-session) | ✅ |
| `composer --version` | ≥ 2.x | `2.9.5` | ✅ |
| `npx tsx scripts/validate_skills.ts` | `All validations passed!` | `Plugin gerard v0.1.0, 53 skills, 3 commands, 3 agents — All validations passed!` | ✅ |
| Fixture bootstrap | Symfony 7.4 + AP 4.3 + SQLite + User entity + schema | ok | ✅ |
| Fixture `bin/console debug:router \| grep api` | API Platform routes registered | `api_entrypoint`, `api_doc`, `api_jsonld_context`, etc. all present | ✅ |
| `session-start.sh` on fixture | runner_type=host, sf=7.4, ap=4.3, framework=phpunit | exact match | ✅ |

Plugin version remains `0.1.0` in `plugin.json` — bump to `1.0.0` is reserved for the end of Session 7.

---

## Test 1 — Happy path (interactive, USER) — PENDING

**Scenario** : `/api "Add Product resource with name, price, status BackedEnum (DRAFT/PUBLISHED/ARCHIVED)"`

**Expected observation chain** :
1. Pre-flight passes — `git status` clean, feature branch created, `/goal` condition composed.
2. `api-architect-trio` dispatches **3 background workers in parallel** (design / aligned / appsec) via `Task(subagent_type=…, run_in_background=true, isolation="worktree")`.
3. `Monitor` returns the three reports, architect-trio synthesizes a plan with verbatim Aligned-Reviewer + AppSec blocks.
4. `api-implementer` reads the plan, dispatches skills (filters / pagination / serialization etc. as relevant), writes `src/ApiResource/Product.php` (or `src/Entity/Product.php` depending on shape) + tests + AppSec mitigations.
5. **PostToolUse hook** auto-runs `phpstan analyse` on every modified `*.php`. No anti-pattern regex triggers (modern code).
6. `gerard-gatekeeper` (fresh session) reads the diff, applies the 39-rule pass, emits `VERDICT: APPROVE`.
7. `/goal` evaluator (Haiku) detects the APPROVE first-line + green tests + no open H1/H2 → clears the goal.
8. Stop hook fires terminal notification.

**Result** : _to be filled by user_

```
[ ] Pre-flight passed
[ ] architect-trio dispatched 3 workers in parallel (Agent View or Monitor confirms)
[ ] Plan synthesized — Aligned-Reviewer + AppSec blocks present verbatim
[ ] Implementer touched Product.php + ApiResource decorations + tests
[ ] PostToolUse phpstan auto-ran (visible in tool stream)
[ ] Gatekeeper APPROVE
[ ] /goal cleared (12-turn cap not reached)
[ ] git diff: code is reasonable
[ ] no #[ApiFilter], no openapiContext, no scalar IDs in payload, BackedEnum status
```

**Observations** :
_user-filled_

**Issues / bugs** :
_user-filled_

---

## Test 2 — Anti-pattern catch (static + isolation) — PASS WITH NOTE

**Scenario from plan** : `/api "Add a Tender resource with #[ApiFilter(SearchFilter::class)] (legacy)"`. Expected : "PostToolUse hook blocks (regex detect `#[ApiFilter`)".

**Static finding** : `docs/anti-patterns.md` L69-81 documents that the PostToolUse hook deliberately scans only **7 highest-signal regex patterns with near-zero false-positive rate**, and `#[ApiFilter]` is **NOT** in that subset — it is rule 1 of the **gatekeeper layer** (full 24-rule pass). The 7 hook regexes are :

1. debug calls (`dd`, `dump`, `var_dump`, `var_export`, `print_r`)
2. TODO/FIXME/XXX
3. `: mixed` return type
4. `@ApiPlatform\` (legacy 3.x annotation)
5. Manual `operations: [new Get(), new GetCollection()]` when defaults would suffice
6. Hard-coded `localhost` / `127.0.0.1` URLs
7. Reserved (extend in your fork)

So the plan énoncé for Test 2 is imprecise — it expects the PostToolUse hook to catch `#[ApiFilter]`, but by design it doesn't. The pattern is still caught downstream :

- The implementer **self-audit** in Step 5 invokes `Skill gerard:meta/anti-patterns-audit` whose checklist has the rule.
- The gatekeeper applies the full 39-rule pass with rule 1 = "no `#[ApiFilter]`".
- Either layer returns `REQUEST_CHANGES`, the loop iterates, the implementer rewrites to `parameters: [new QueryParameter(...)]`.

**Tested in isolation against `hooks/post-tool-use.sh`** :

| Pattern in test PHP file | Hook decision | ✅/❌ |
|---|---|---|
| `dd($this);` | `block` with reason "debug call must not ship" | ✅ |
| `// TODO: implement` | `block` with reason "TODO/FIXME forbidden" | ✅ |
| `#[ApiFilter(SearchFilter::class, ...)]` | (no block — not in the 7-regex subset by design) | ✅ (matches doc) |

**Verdict** : the hook is conformant with `docs/anti-patterns.md`. The `#[ApiFilter]` catch is delegated to the implementer self-audit (via `meta/anti-patterns-audit`) and to the gatekeeper full pass. The interactive Test 2 (when user runs it) will confirm that **a** layer of the pipeline blocks the pattern — that is the real contract.

The plan énoncé wording should be reinterpreted as "some pipeline layer blocks", not specifically "the PostToolUse hook blocks". No code change required.

**Recommendation** : when the user runs `/api "Add Tender resource with legacy filter"` in interactive mode (optional), confirm that the gatekeeper rejects on rule 1 and that the implementer iterates to the modern `parameters: [QueryParameter]` shape.

---

## Test 3 — Secret protection (static + isolation) — PASS WITH NOTE

**Scenario** : force the implementer to write `.env.local`. Expected : `PreToolUse` hook denies.

**Tested in isolation against `hooks/pre-tool-use.sh`** :

| `tool_name` | `file_path` | Decision | ✅/❌ |
|---|---|---|---|
| `Write` | `/app/.env.local` | `deny` (JSON output with `hookSpecificOutput.permissionDecision=deny`) | ✅ |
| `Write` | `/app/.env` | `deny` | ✅ |
| `Write` | `/home/user/.ssh/id_rsa` | `deny` | ✅ |
| `Write` | `/app/credentials.json` | `deny` | ✅ |
| `Write` | `/tmp/Product.php` | (no block, exit silent — pass) | ✅ |

**Finding (mineur — UX, not security)** : `.env.dist` is also denied (case `.env.*` is too broad). `.env.dist` is the Symfony convention for *example files without secrets* — it is meant to be committed and edited freely. The hook intentionally errs on the side of strictness, but a user who is told by the implementer "I'll add the value to `.env.dist`" will see the write denied with the same secret-pattern message.

Workarounds documented in plugin behavior :
- The user manually edits `.env.dist`.
- The reason message in the hook tells Claude to ask the user.

Severity : low. Not a v1.0 blocker. Could be tightened in v1.1 with an explicit allow-list of conventional `.env.dist`, `.env.example`, `.env.sample`.

**Verdict** : ✅ the hook blocks all secret-pattern writes. The `.env.dist` false-positive is documented as a known UX limit.

---

## Test 4 — Memory accumulation (interactive, USER) — PENDING

**Scenario** : after Test 1 clears, run `/api "Add Category resource"`. Expected : `agents/api-implementer/memory/` now contains a Test 1 entry (e.g. `quality-gate-commands.md`, `runner-selection.md`, `voter-pattern.md`, or any topic the implementer learned).

**Result** : _to be filled by user_

```
[ ] Test 1 left at least one .md file in agents/api-implementer/memory/
[ ] (optionally) gatekeeper memory accumulated something
[ ] Test 4 implementer reads memory/ first (visible in tool stream)
[ ] Test 4 is observably faster OR more aligned (subjective; count tool calls or wall-clock seconds if possible)
[ ] Memory file is concise (≤ 30 lines), not a journal
```

**Observations** :
_user-filled_

---

## Test 5 — /api-finalize dry-run (static markdown review) — PASS

**Scenario** : after Test 1 cleared, run `/api-finalize --no-push --no-pr`. Expected : commit message composed from the gatekeeper report, explicit per-file staging, secrets skipped, no push, no PR.

**Static review of `commands/api-finalize.md`** :

| Step | Check | ✅/❌ |
|---|---|---|
| 1. Pre-flight | git repo / not-on-main / non-empty status / no rebase-in-progress | ✅ all in the markdown |
| 2. Parse flags | `--no-push`, `--no-pr` | ✅ documented |
| 3. Staging list | EXCLUDE rules (`.env*`, `*.pem`, `*.key`, `*credentials*`, `*.kdbx`, `.claude/last-api-*.md`, `.claude/api-*.tmp`, `.claude/memory-snapshots/`); INCLUDE all else | ✅ matches the PreToolUse pattern list (single source of truth) |
| 3. Staging method | `git add -- <path1> <path2>` (no `-A` / `.`) | ✅ explicit |
| 4. Commit message | scope + imperative subject ≤ 72 / Why / What / Verification template | ✅ structured |
| 4. No Claude trailer | "Do NOT add a 'Generated by Claude' trailer" | ✅ |
| 5. Commit method | HEREDOC, no `--amend`, no `--no-verify`, no `--no-gpg-sign` | ✅ |
| 6. Push (skip on `--no-push`) | infer upstream, never `--force` | ✅ |
| 7. PR (skip on `--no-pr`, skip if `gh` missing) | template with Summary / How it was built / Test plan / AppSec / Out of scope | ✅ |
| 8. Final report | one-line success | ✅ |

The command is a markdown contract that Claude Code interprets : the `!` bang-commands at the top run via Bash, the rest is logic Claude follows. The interactive run (when triggered after Test 1) is mostly determined by the gatekeeper report quality (Verification block) and the staging discipline (per-file).

**Confidence** : high. Static review covers the deterministic parts. The only failure modes that would surprise are :
- Claude not following the markdown faithfully (low probability — the file is short and uses anchors `!command`).
- A pre-commit hook on the user's machine that rejects the commit (out of scope of plugin).

**Verdict** : ✅ pass on static review. Interactive confirmation by the user when they reach Test 5 is welcome but not required for v1.0 release.

---

## Static findings summary

| # | Finding | Severity | Action for v1.0 |
|---|---|---|---|
| F1 | Validator scans `agents/*.md`, but v1.0 uses `agents/<name>/agent.md`. Was "Found 0 valid agents". | High (silent miss) | **Fixed** in commit `206b66e` |
| F2 | `.env.dist` denied by PreToolUse — false positive on a conventional example file. | Low UX | Documented. Defer to v1.1. |
| F3 | Plan énoncé for Test 2 ("PostToolUse blocks `#[ApiFilter`") is imprecise. Hook intentionally has only 7 high-signal regexes per `docs/anti-patterns.md`. `#[ApiFilter]` is rule 1 of the gatekeeper. | None (doc-aligned) | Reinterpret the plan énoncé. No code change. |
| F4 | UserPromptSubmit hook : keyword `search` matches `filter\|search\|sort\|order` → `api-platform-filters` even when context is McpTool search. False positive on hint only — not blocking. | Low | Defer to v1.1. |

---

## Interactive E2E findings (user-filled)

_user-filled at the end of Tests 1 + 4_

---

## Verdict

_Conditional on Tests 1 + 4 interactive results._

If both Tests 1 and 4 pass with no high-severity findings :
- **READY for v1.0.0-rc1 tag.**
- Bump `plugin.json` and `marketplace.json` version to `1.0.0`.
- Then await user validation for the production `v1.0.0` tag and the merge into `main`.

If Test 1 or 4 surface a blocker :
- Fix iteratively (max 3 iterations per scenario, then escalate).
- Re-run the affected test.
- Update this report.
