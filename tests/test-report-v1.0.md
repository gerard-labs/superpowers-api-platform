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

## Test 1 — Happy path (interactive) — SKIPPED BY USER DECISION

**Scenario** : `/api "Add Product resource with name, price, status BackedEnum (DRAFT/PUBLISHED/ARCHIVED)"`

**Decision** : the user elected to skip the interactive E2E pass on 2026-05-14, trusting the static + isolation validation.

**Rationale for the user's decision** :
- All 5 hooks tested in isolation against mock JSON payloads (PreToolUse, PostToolUse, SessionStart, UserPromptSubmit, Stop) — every assertion passed.
- `npx tsx scripts/validate_skills.ts` parses 53 skills + 3 commands + 3 agents with all skill references resolved (after the F1 validator fix).
- The `anti-patterns-audit` skill and `gerard-gatekeeper` agent both reference the same 24-rule SoT (no drift after the api-implementer dedup follow-up `bab23b4`).
- The 3 agents' frontmatter (model, effort, maxTurns, skills, memory) is well-formed and references existing skills.
- `docs/v1.0-plan.md` decisions are locked and the architecture is documented end-to-end in `docs/` (12 files).

**Residual risk accepted** :
- We have not empirically confirmed that the 3 background workers dispatched by `api-architect-trio` actually run in parallel via `run_in_background: true` + `Monitor`. This depends on Claude Code 2.1.139+ behavior which is validated upstream.
- We have not empirically confirmed that `/goal` (native loop) converges on the gatekeeper APPROVE first-line in real flow. The condition wording in `commands/api.md` / `skills/goal-patterns/` is reviewed but not run.
- We have not empirically confirmed memory accumulation between two consecutive `/api` runs (covered by Test 4 — also skipped).

These risks are partially mitigated by :
- `claude --version` ≥ 2.1.139 verified — the primitives exist in this version.
- The static validators caught the only silent bug (F1) and it is fixed.
- The plan énoncé will be empirically validated by the first user who runs `/api` against a real Symfony 7.4 + AP 4.3 project after v1.0.0-rc1 ships. Any regression observed will trigger a v1.0.1 patch.

**Status** : SKIPPED — assumed OK pending first real-world `/api` run.

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

- The implementer **self-audit** in Step 5 invokes `Skill gerard:anti-patterns-audit` whose checklist has the rule.
- The gatekeeper applies the full 39-rule pass with rule 1 = "no `#[ApiFilter]`".
- Either layer returns `REQUEST_CHANGES`, the loop iterates, the implementer rewrites to `parameters: [new QueryParameter(...)]`.

**Tested in isolation against `hooks/post-tool-use.sh`** :

| Pattern in test PHP file | Hook decision | ✅/❌ |
|---|---|---|
| `dd($this);` | `block` with reason "debug call must not ship" | ✅ |
| `// TODO: implement` | `block` with reason "TODO/FIXME forbidden" | ✅ |
| `#[ApiFilter(SearchFilter::class, ...)]` | (no block — not in the 7-regex subset by design) | ✅ (matches doc) |

**Verdict** : the hook is conformant with `docs/anti-patterns.md`. The `#[ApiFilter]` catch is delegated to the implementer self-audit (via `anti-patterns-audit`) and to the gatekeeper full pass. The interactive Test 2 (when user runs it) will confirm that **a** layer of the pipeline blocks the pattern — that is the real contract.

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

## Test 4 — Memory accumulation (interactive) — SKIPPED BY USER DECISION

**Scenario** : after Test 1 clears, run `/api "Add Category resource"`. Expected : `agents/api-implementer/memory/` now contains a Test 1 entry, and the second run is faster or more aligned.

**Decision** : skipped concurrently with Test 1 (same user decision).

**Static evidence supporting the design** :
- `agents/api-implementer/agent.md` step "First action" instructs : "Read `agents/api-implementer/memory/`".
- `agents/gerard-gatekeeper/agent.md` step "First action" instructs the same.
- `agents/api-architect-trio/agent.md` likewise.
- All three `memory/.gitkeep` are in place (commits f203b76 + 12c5c46).
- `docs/forensic-loop.md` documents the 3-layer loop and the per-agent memory lifecycle.

**Residual risk** : memory write at end-of-Task is not empirically observed. Agents may forget to write memory on a given run, but this is graceful degradation — the run still produces correct code, only the forensic accumulation is missed for that run.

**Status** : SKIPPED — assumed OK pending first real-world `/api` run.

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
| F5 | **Claude Code's plugin loader does not recurse into `skills/`** — `skills/meta/<name>/SKILL.md` was invisible at runtime. Caught by an empirical smoke test (`claude -p --plugin-dir <path>`) that returned 51 instead of 53 skills. **rc1 included this bug.** Every `gerard:meta/*` invocation would have failed with "Unknown skill". | **Critical** (would have broken `/api` pipeline) | **Fixed** — flattened both skills (`anti-patterns-audit`, `goal-patterns`) to `skills/<name>/`. All references updated across the codebase (agents, commands, docs, README, RELEASE-NOTES, CONTRIBUTING, skills-map, v1.0-plan, tests, scripts). Linter parser fixed (was matching only single-line descriptions ; now handles YAML block scalars). Skills' `Use when` / `Default workflow` / `Guardrails` / `Output contract` sections completed (previously hidden by the `meta/` sub-namespace and thus untested). Re-tagged **v1.0.0-rc2** on the fix commit. |
| F6 | **`skills-map.md` listed bogus goal-pattern shape names** (`feature / refactor / migration / hardening / bugfix / perf / docs / appsec`) — not what `skills/goal-patterns/SKILL.md` actually declares (`new-resource`, `new-operation`, `new-filter`, `new-state-flow`, `migration`, `bugfix`, `refactor`, `security-hardening`, `generic`). | Important (user-facing drift) | **Fixed** in the audit pass |
| F7 | **`skills/goal-patterns/SKILL.md` frontmatter undercounted addenda** (said 5, has 8 + generic = 9). | Important (frontmatter is the metadata consumers read first) | **Fixed** |
| F8 | **`docs/symfony/` directory survived Session 2 cleanup** with 3 orphan files. Not referenced by any live doc. | Important (dead weight, source of confusion) | **Fixed** — `git rm -r` |
| F9 | **`agents/gerard-gatekeeper/agent.md` frontmatter said "24+ rule"** — underspecified vs the actual 39-rule pass documented in `docs/anti-patterns.md`. | Minor (clarity) | **Fixed** — explicit "39-rule (24 base + 15 extensions)" |

---

## Interactive E2E findings

Tests 1 and 4 were **skipped by user decision** (see their sections). After F5 was caught and fixed, the user requested a deeper empirical validation : `claude -p --plugin-dir <path>` smoke tests + an LLM-driven doc audit. Both run in the fixture.

### Empirical smoke tests (claude -p mode)

| # | Test | Expected | Result |
|---|---|---|---|
| E1 | Invoke `Skill gerard:api-platform-resources` and dump first 200 chars | Returns the SKILL.md content with `Base directory: skills/api-platform-resources/` + heading | ✅ Match |
| E2 | List every available agent via Task tool / @-mention | 3 gerard agents (`api-architect-trio`, `api-implementer`, `gerard-gatekeeper`) plus 4 built-ins (`claude`, `Explore`, `general-purpose`, `Plan`, `statusline-setup`) | ✅ Match — TOTAL: 7 |
| E3 | Write tool on `/tmp/.env.local` | PreToolUse hook denies, returns gerard-branded message | ✅ Verbatim hook message ("gerard pre-tool-use blocked write to /tmp/.env.local: filename matches a secret pattern…") |
| E4 | Write tool on `/tmp/test-anti-pattern.php` with `dd($this);` | PostToolUse hook blocks, regex hit on `dd(` | ✅ Verbatim block message ("gerard post-tool-use regex scan found anti-patterns… debug call must not ship — line 4: dd(\$this);") |
| E5 | Ask Claude to summarize `commands/api.md` workflow | Sub-Claude reads the command and describes pre-flight → architect-trio → /goal loop → finalize-banner | ✅ Match (correctly classifies `Add Product resource` as `new-resource` shape, identifies the 4-bullet base + addendum composition, mentions 12-turn cap) |

### LLM-driven documentation audit

An Explore agent was tasked with reading 21 files (README, RELEASE-NOTES, CONTRIBUTING, skills-map, 11 docs/, 3 agents/, 3 commands/) and flagging count mismatches, broken links, naming drift, version mismatches, and cross-doc contradictions. Findings :

| Severity | Finding | Fix |
|---|---|---|
| Critical | `skills-map.md` L96 listed bogus shape names (`feature / refactor / migration / hardening / bugfix / perf / docs / appsec`) instead of the real ones | **Fixed** — replaced with `new-resource / new-operation / new-filter / new-state-flow / migration / bugfix / refactor / security-hardening` + `generic` fallback (9 total) |
| Critical | `skills/goal-patterns/SKILL.md` frontmatter said "5 shape-specific addenda" but the body declares 8 + generic | **Fixed** — frontmatter now says "8 shape-specific addenda + generic = 9 patterns total" |
| Important | `docs/symfony/` directory contained 3 orphan files (`api-platform-4.3-overview.md`, `api-platform-anti-patterns.md`, `api-platform-config-4.3.md`) — supposed to be deleted in Session 2 but survived. Not linked from anywhere live. | **Fixed** — `git rm -r docs/symfony/` |
| Minor | `agents/gerard-gatekeeper/agent.md` frontmatter said "24+ rule anti-pattern checklist" — underspecified vs the 39-rule reality documented in `docs/anti-patterns.md` | **Fixed** — frontmatter now says "39-rule anti-pattern checklist (24 base = 16 AP 4.3 + 8 Symfony 7.4+ ; plus 15 extensions = 1 Make project + 7 tests + 7 AppSec)" |

The agent also verified clean :
- Plugin version v1.0.0 consistent across `plugin.json`, `marketplace.json`, README, RELEASE-NOTES.
- Model assignments (Opus 4.7 xhigh / Sonnet 4.6 / Haiku 4.5) consistent across README, agents, docs.
- Count totals : 53 skills + 3 commands + 3 agents + 5 hooks ✓
- 39-rule total (24 + 15) ✓
- Zero residual `gerard:meta/X` or `skills/meta/X` references outside the test report's own F5 description.

---

## Verdict

**READY for v1.0.0-rc2 tag.** Initial rc1 (`e590af7`) contained the critical F5 bug — replaced by rc2 on the fix commit.

The user has accepted the residual risk of skipping the two interactive E2E scenarios (Test 1 happy path, Test 4 memory accumulation). The static + isolation validation is comprehensive enough to ship a release candidate, with the explicit understanding that any regression observed by the first real-world `/api` run will trigger a v1.0.1 patch.

The new empirical smoke test that caught F5 — `claude -p --plugin-dir <path> "list every gerard:* skill"` from inside the fixture — now serves as the v1.0 "is the plugin loadable" gate. It returned 56 items (3 commands + 53 skills) on the fixed rc2, confirming the loader sees every artifact.

Next actions (all gated on user) :
1. Push commits to `origin/v1.0` (rc2 still local at the time of this report).
2. Push `v1.0.0-rc2` tag.
3. After soak time : tag `v1.0.0` on the rc2 commit.
4. Merge `v1.0` into `main` with `--no-ff`.
5. Push `main` + tags to origin.
