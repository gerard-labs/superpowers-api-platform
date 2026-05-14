---
description: TOTAL AUTONOMY — branch + pipeline + commit + push + PR for an API Platform feature. Refuses dirty tree. Loop REQUEST_CHANGES cap 3. Skips secrets.
argument-hint: "<feature description in 1-3 sentences>"
allowed-tools: Task, Read, Write, Edit, Bash, Glob, Grep
---

# /api-resource-ship — Total autonomy mode

Run the full agentic pipeline on this API Platform feature, **without any human intervention**, until either:
- the feature is APPROVED → committed + pushed → PR opened (if `gh` available)
- the request_changes cap is reached → escalation block printed for the human to review

Feature description:

$ARGUMENTS

## ⚠️ Autonomy contract

- You DO NOT ask for confirmation at any step
- You DO NOT print "shall I continue?"
- You DO NOT pause for review
- You DO commit and push automatically on APPROVE
- You DO NOT push to `main` directly — always a feature branch
- You DO NOT use `--force`, `--no-verify`, `--no-gpg-sign`
- You SURFACE every stage's output so the human can audit a posteriori

## Pre-flight

1. **Verify clean working tree** :
   ```bash
   git status --porcelain
   ```
   If output is non-empty → **STOP**. Print: "Refusing /api-resource-ship on a dirty working tree. Stash or commit first."

2. **Slugify the feature** (lowercase, kebab-case, max 50 chars). Example: `add-tender-csv-export`.

3. **Detect base branch** (`main` typically). Verify we are on it or fork from it :
   ```bash
   git fetch origin main
   git checkout -B feat/api-<slug> origin/main
   ```

## Pipeline

### Stage 1 — Architecture
Run `/architect $ARGUMENTS` (saves to `.claude/last-api-plan.md`).

### Stage 2 — Dev
Run `/dev`.

### Stage 3 — Test
Run `/test`.

### Stage 4 — Review
Run `/review` (saves verdict to `.claude/last-api-review.md`).

### Loop on REQUEST_CHANGES

If `.claude/last-api-review.md` first non-empty line is `VERDICT: REQUEST_CHANGES`:

```
iteration = 1
while iteration <= 3:
  iteration += 1
  Run /dev   # implementer reads the latest review feedback
  Run /test
  Run /review
  if VERDICT: APPROVE → break
```

If after 3 iterations still `REQUEST_CHANGES` → **ESCALATE**:
- Print the persistent issues
- Print: "Escalation: 3 iterations exhausted. Branch left at `feat/api-<slug>`. Read `.claude/last-api-review.md` for the persistent issues."
- **STOP** (do not commit, do not push)

### Stage 5 — Commit + push (only on APPROVE)

1. **Compose commit message** from the plan + dev report :
   - Subject: `feat: <story summary in 50 chars max>` (drawn from `.claude/last-api-plan.md` story description)
   - Body: 2-3 sentences describing the why + the what (drawn from plan §1 and §2 + dev report)
   - Trailer: `Co-authored-by: Claude <noreply@anthropic.com>` (optional)

2. **Stage the diff explicitly** (never `git add -A`) :
   ```bash
   git status --porcelain
   # → list each modified/added file by name
   git add <each-file-explicitly>
   ```
   **Skip any file matching** : `.env*`, `*.local.*`, `*credentials*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`.

3. **Commit** :
   ```bash
   git commit -m "<subject>" -m "<body>"
   ```
   If pre-commit hook fails: read the failure, fix it, re-stage, **NEW commit** (never `--amend`).

4. **Push** :
   ```bash
   git push -u origin feat/api-<slug>
   ```

5. **Open PR (if `gh` available)** :
   ```bash
   gh --version  # check available
   gh pr create --title "<subject>" --body "$(cat <<EOF
   ## Summary
   <2-3 bullets from plan summary>

   ## API Platform area
   <area from plan header>

   ## Test plan
   - [x] phpunit --filter=Api green (Tests: N, Assertions: M verbatim from test report)
   - [x] phpstan analyse green
   - [x] Infection per-target MSI per critical class (verbatim from test report)
   - [x] Reviewer APPROVE (`.claude/last-api-review.md`)

   ## State files (gitignored)
   - `.claude/last-api-plan.md`
   - `.claude/last-api-dev-report.md`
   - `.claude/last-api-test-report.md`
   - `.claude/last-api-review.md`

   🤖 Generated with /api-resource-ship autonomy mode
   EOF
   )"
   ```

6. **Final report** :
   ```
   ✅ API feature shipped autonomously
      Branch:        feat/api-<slug>
      Commits:       <count>
      Files:         <count> modified
      Iterations:    <N> (out of 3 max)
      PR URL:        <url if gh succeeded, else "PR not created (gh missing)">
   ```

## Failure modes

- **Dirty working tree** → /api-resource-ship refuses to start.
- **3 iterations exhausted** → branch left in place, no commit, escalation message.
- **Pre-commit hook fails repeatedly** → escalation, branch left in place.
- **Push fails (auth, branch protection)** → escalation, branch + commits intact locally.
- **`gh pr create` fails** → commit + push succeeded, PR creation step skipped with note.

The human always retains control:
- `git checkout main && git branch -D feat/api-<slug>` → discard the autonomous attempt
- Manual `gh pr create` from the pushed branch
- Re-running individual stages: `/architect`, `/dev`, `/test`, `/review`

## Safety net summary

| Risk | Mitigation |
|---|---|
| Pushes broken code | Reviewer APPROVE required before commit (24+ anti-patterns checklist) |
| Pushes to main | Always pushes to `feat/api-<slug>` |
| Force-pushes | `--force` denied at the `.claude/settings.json` level (project consumer should enforce) |
| Skips hooks | `--no-verify` denied at settings.json level |
| Loses work | All sub-reports saved to `.claude/last-api-*.md` for replay |
| Infinite loop | Cap of 3 iterations on REQUEST_CHANGES |
| Commits secrets | Explicit per-file `git add` skipping `.env*`, `*credentials*`, `*.pem`, `*.key`, `*.p12`, `*.pfx` |
| Rubber-stamp | Reviewer enforces evidence block + cap unverified claims + skill-theatre detection |
