# Troubleshooting

> Common failure modes and how to debug them. Each section names the symptom, lists likely causes, and shows the verification step.

## Index

- [Goal doesn't clear](#goal-doesnt-clear)
- [Hook blocks unexpectedly](#hooks)
- [Agents fail to dispatch](#agents-fail-to-dispatch)
- [Memory not persisting between sessions](#memory-not-persisting-between-sessions)
- [Claude Code version too old](#claude-code-version-too-old)
- [Session-start hook produces wrong runner_type](#session-start-hook-produces-wrong-runner_type)
- [`/api-finalize` excludes a file I want to commit](#api-finalize-excludes-a-file-i-want-to-commit)
- [`/api-doctrine import` clobbers live memory](#api-doctrine-import-clobbers-live-memory)
- [Skill validator rejects `meta/`](#skill-validator-rejects-meta)
- [PHPStan hook timeout](#phpstan-hook-timeout)

---

## Goal doesn't clear

**Symptom** : `/api` runs to the 12-turn cap without `/goal` clearing.

**Likely causes** :

1. **Gatekeeper keeps returning `REQUEST_CHANGES`** — there are real anti-patterns in the diff. Check the gatekeeper's last verdict ; the numbered findings list tells you what to fix.
2. **AppSec H1/H2 finding not mitigated** — bullet 2 of the base condition. Look at the gatekeeper's AppSec bilan table : any row with status ≠ `resolved` blocks the goal.
3. **Tests not green** — bullet 3. Run the project's test command manually (`make tests`, `./vendor/bin/phpunit --filter=Api`, etc.) and check.
4. **Hook flagged anti-patterns recently** — bullet 4 (last 3 tool calls). If the implementer just hit a regex / phpstan block, give it a tool call or two to settle.
5. **Hedge language in the condition** — if you customized `goal-patterns` to add fuzzy bullets like *"ideally APPROVE"*, the Haiku evaluator may not match. Use unambiguous language.

**Verification** :

```text
/api "<story>"
# Watch the verdict line from the last gatekeeper Task return.
# Read the AppSec bilan table.
# Run the test command from session-start commands.test manually.
```

If you're stuck, re-run with `--interactive` to inspect the plan and provide guidance.

---

## Hooks

### PreToolUse blocks legitimate work

**Symptom** : `pre-tool-use.sh` denies an edit to a file that isn't actually a secret.

**Cause** : the file's basename matches the secret pattern list (`.env*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*credentials*`, `*.crt`, ssh keys, `*.kdbx`).

**Fix** :

- If the file legitimately contains secrets : ask the user to edit it manually (outside Claude). The hook is doing its job.
- If the file's name accidentally matches (e.g. `customer-credentials-template.md` — not actually a secret) : rename the file. The hook doesn't support a bypass on purpose — making the bypass easy would defeat the protection.

### PostToolUse blocks on a false positive

**Symptom** : `post-tool-use.sh` flags an anti-pattern on a file that legitimately needs the pattern (e.g. you're editing `skills/api-platform-upgrade/SKILL.md` which intentionally documents `#[ApiFilter]`).

**Cause** : the regex pass doesn't have a context-aware exemption.

**Fix** :

- For `skills/api-platform-upgrade/*` : these files document legacy patterns on purpose. The current hook does not exempt them. Workaround : disable hooks temporarily (`--disable-all-hooks`) for that specific edit, or edit the file via your editor outside Claude.
- For other legitimate false positives : add a memory entry to `agents/gerard-gatekeeper/memory/false-positive-<topic>.md` documenting the case, and consider opening an issue to refine the regex.

### PostToolUse runs phpstan and times out

**Symptom** : 30-second timeout fires, Claude continues silently.

**Cause** : phpstan analysis on a large file or with broad config. The hook treats timeout (exit 124) as a soft-skip — phpstan errors that needed 60s won't be caught.

**Fix** : the gatekeeper still runs a full pass. Inline timeout is best-effort. If you want stricter inline analysis, tune phpstan config (`level: 8` vs `level: 9+`, fewer rules) or run phpstan manually as part of your test command.

---

## Agents fail to dispatch

**Symptom** : `/api` step 5 (architect-trio dispatch) reports an error or returns without a plan.

**Likely causes** :

1. **Claude Code version too old** (most common). The architect-trio needs `Agent` with `run_in_background=true` and `isolation="worktree"`, plus `Monitor`. Verify : `claude --version` ≥ 2.1.139.
2. **`isolation: "worktree"` failing** — worktrees need a clean working tree at dispatch time. The `/api` pre-flight already checks this, but if something landed in the tree between pre-flight and dispatch (e.g. you ran a manual command), retry.
3. **Disk space** — worktrees clone the repo. If you're near disk capacity, worktree creation can fail.

**Verification** :

```bash
# In your shell
claude --version
git status --porcelain
df -h .
```

---

## Memory not persisting between sessions

**Symptom** : you ran `/api` last week ; the agent had written memory entries ; today's agent doesn't seem to recall them.

**Likely causes** :

1. **The memory dirs were emptied** — `agents/*/memory/` is in the plugin install dir (`~/.claude/plugins/marketplaces/superpowers-api-platform/agents/*/memory/`). If you reinstalled the plugin, you may have wiped the memory.
2. **The agent ran on a different repo** — memory is at the plugin level, but the agent's memory entries reference the active project. If you switched projects, the entries may be about a different codebase.
3. **`/clear` wiped Claude Code's conversation context** but memory dirs survived — verify by reading the agent's memory dir directly :
   ```bash
   ls ~/.claude/plugins/marketplaces/superpowers-api-platform/agents/api-implementer/memory/
   ```
4. **Dreaming compressed entries** — recent entries should still be present ; check if older entries got archived. Dreaming is opt-in at the Claude Code level.

**Fix** :

- If you have a snapshot : `/api-doctrine import <name>`.
- Otherwise, accept the reset and let memory accumulate again. Going forward, `/api-doctrine export` at meaningful milestones.

---

## Claude Code version too old

**Symptom** : at session start, you see a warning like :

```text
gerard session-start: Claude Code 2.1.137 detected. v1.0 needs ≥ 2.1.139
                      for native /goal + Monitor + worktree isolation.
                      Consider upgrading: claude update.
```

**Fix** : `claude update`. The required primitives are :

- `/goal` (native multi-turn loop with verifiable condition) — 2.1.139+
- `Monitor` tool (stream completion events from background agents) — 2.1.139+
- `Agent` with `isolation: "worktree"` (run agent in an isolated worktree) — 2.1.139+
- `terminalSequence` hook field (Stop hook desktop notification) — 2.1.119+
- `additionalContext` hook field (UserPromptSubmit injection) — 2.1.119+

If you can't update right now : you can still use the plugin partially. `/api` won't work (architect-trio dispatch fails), but you can invoke skills directly (`Skill gerard:api-platform-filters`) and reference agents (`@agent-api-implementer`). The atomic capabilities still ship.

---

## Session-start hook produces wrong `runner_type`

**Symptom** : your project is a DDEV project but `session-start.sh` reported `runner_type: host`.

**Likely causes** :

1. **`.ddev/` directory is missing or untracked** — DDEV detection requires `.ddev/` at the orchestration root.
2. **Orchestration root walk fell short** — the hook walks up to 4 levels by default. If your `.ddev/` is deeper or higher, it may not be reached.
3. **Monorepo with `.ddev/` in a sub-app** — the hook expects orchestration markers at or above the `composer.json` location.

**Verification** :

```bash
# Where is the active composer.json?
find . -name composer.json -not -path '*/vendor/*' -not -path '*/node_modules/*'

# Where is .ddev/?
find . -name '.ddev' -type d -not -path '*/vendor/*'

# Are they in a reasonable parent relationship?
```

**Fix** : if the structure is non-standard, the hook may need a manual override. Edit `hooks/session-start.sh` `find_orchestration_root` to extend `max_depth` or hard-code the path for your case.

---

## `/api-finalize` excludes a file I want to commit

**Symptom** : `/api-finalize` lists a file as excluded with reason "matches secret pattern" or "legacy state file", but you genuinely want it committed.

**Cause** : the exclusion rules are strict by design (mirror the PreToolUse secret patterns + legacy state files).

**Fix** :

- **Secret-shaped name** : `git add -- <path>` manually after `/api-finalize` builds the staging list. Then re-run `/api-finalize` ; the file is already staged so it'll be picked up. Note : this bypass should be used sparingly — verify the file is genuinely safe to commit.
- **Legacy state file** : if you actually want to commit `.claude/last-api-foo.md` (rare), same workaround.

If you keep needing this for a non-secret file, rename the file to a non-matching pattern.

---

## `/api-doctrine import` clobbers live memory

**Symptom** : after `/api-doctrine import <name>`, your live memory entries seem replaced.

**Cause** : if a target filename already existed locally when importing, the import was supposed to suffix `-imported-<timestamp>` to the new file. If that didn't happen :

1. **The clobber-protection has a bug** — open an issue with the exact snapshot name and the file affected.
2. **You imported deliberately wanting to overwrite** — the command may have asked confirmation. The default is "rename to avoid clobber" ; if you explicitly chose "overwrite", that's the answer.

**Fix** :

- Git is your safety net : `git diff agents/*/memory/` shows what changed. `git checkout -- agents/*/memory/` to revert.
- The snapshot file itself is unchanged — re-import or hand-pick the entries.

---

## Skill validator rejects `meta/`

**Symptom** : `npx tsx scripts/validate_skills.ts` reports "Missing SKILL.md" on `skills/meta/`.

**Cause** : the validator originally scanned `skills/<dir>/SKILL.md` strictly, but `skills/meta/` is a namespace (its sub-dirs `meta/anti-patterns-audit/`, `meta/goal-patterns/` are the actual skills).

**Fix** : ensure you're on Session 5's patched validator (commit `73f71f6` or later). The patch adds a `SKILL_NAMESPACES = new Set(['meta'])` and recursion. If you customized the validator and removed the namespace logic, re-add it.

If you cloned a v0.1 fork, you may need to backport the validator patch from v1.0.

---

## PHPStan hook timeout

**Symptom** : the PostToolUse hook reports a phpstan timeout after 30 seconds. Anti-pattern that phpstan would have caught isn't blocked.

**Cause** : phpstan analysis on a large file or with broad config exceeds 30s. The hook treats timeout as soft-skip (exit 124).

**Fix** :

- The gatekeeper still runs a full pass — the inline phpstan is best-effort, not a replacement.
- If you want stricter inline coverage, tune phpstan config :
  - Narrow `level` (`level: 8` is often enough for inline ; `level: 9+` for the project-level CI run)
  - Reduce the `paths:` to the changed file only (the hook already passes a single file)
  - Add `tmpDir` config to a fast SSD location

---

## Hook does nothing visibly

**Symptom** : you see no output from a hook (e.g. UserPromptSubmit) and aren't sure if it's running.

**Cause** : the hooks exit silently in the no-op path so they never pollute the terminal during normal use. They only emit JSON when there's something to inject or block.

**Verification** :

```bash
# Trace the hook manually:
echo '{"prompt": "/api \"Add Product resource\""}' | bash ~/.claude/plugins/marketplaces/superpowers-api-platform/hooks/user-prompt-submit.sh
```

You should see the additionalContext JSON when the prompt matches `/api`. If you see nothing, the hook didn't match — check the regex in the script.

---

## I disabled all hooks for debugging — what do I lose?

**Symptom** : you ran `--disable-all-hooks` for debugging. Now `/api` runs but feels "lighter".

**What you lose** :

- **SessionStart** : agents fall back to generic commands (`./vendor/bin/phpunit`) instead of project-canonical (`make tests`). Implementer becomes less project-aware.
- **UserPromptSubmit** : skills aren't pre-fetched. Agents may re-discover skills they could have skipped to.
- **PreToolUse** : secret patterns aren't blocked. Be careful what you write.
- **PostToolUse** : anti-patterns and phpstan errors aren't caught inline ; the gatekeeper catches them later (more round-trips).
- **Stop** : no desktop notification when the goal clears.

**Recommendation** : re-enable hooks for normal work. `--disable-all-hooks` is for debugging the hooks themselves, not for production use.

---

## Still stuck?

1. Check [`v1.0-plan.md`](v1.0-plan.md) for the full rationale of each decision — sometimes "this is the intended behavior" is the answer.
2. Search existing issues : [github.com/gerard-labs/superpowers-api-platform/issues](https://github.com/gerard-labs/superpowers-api-platform/issues).
3. Open a new issue with :
   - The exact command you ran
   - The output you got (especially the gatekeeper's verdict and EVIDENCE block if relevant)
   - `claude --version`
   - The session-start hook's env JSON (look for the system reminder area in the conversation)

---

## References

- [`how-it-works.md`](how-it-works.md) — what each stage does (helps localize the failure)
- [`hooks.md`](hooks.md) — full hook reference
- [`agents.md`](agents.md) — full agent reference
- [`commands.md`](commands.md) — command reference
- [`anti-patterns.md`](anti-patterns.md) — what the gatekeeper enforces
