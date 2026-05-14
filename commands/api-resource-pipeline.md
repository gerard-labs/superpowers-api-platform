---
description: Chain all 4 stages on an API Platform feature (semi-auto). STOPS before commit so you can inspect the diff. Loop REQUEST_CHANGES cap 3.
argument-hint: "<feature description in 1-3 sentences>"
allowed-tools: Task, Read, Write, Edit, Bash, Glob, Grep
---

# /api-resource-pipeline — semi-autonomous

Run the full agentic pipeline on this API Platform feature:

$ARGUMENTS

**Difference vs `/api-resource-ship`** : this command **stops before the git commit** so you can inspect the diff. `/api-resource-ship` commits and pushes autonomously.

## Steps

1. Run `/architect $ARGUMENTS` — saves plan to `.claude/last-api-plan.md`.
2. Run `/dev` — implements + saves to `.claude/last-api-dev-report.md`.
3. Run `/test` — verifies + saves to `.claude/last-api-test-report.md`.
4. Run `/review` — emits verdict, saves to `.claude/last-api-review.md`.
5. **If verdict = REQUEST_CHANGES** :
   - Read the change list from `.claude/last-api-review.md`
   - Re-run `/dev` (the implementer reads the latest review feedback)
   - Re-run `/test`
   - Re-run `/review`
   - **Cap at 3 iterations**. Beyond, output the persistent issues for the user. **STOP** without commit, branch (if any) left in place.
6. **If verdict = APPROVE** :
   - Summarize what was built (1 paragraph)
   - List the files touched with line counts (`git diff --stat`)
   - Show `git diff --stat` actual
   - Prompt the user: "Diff ready. Inspect with `git diff`, then commit and push manually OR run `/api-resource-ship <description>` next time to skip the manual step."

## Verdict parsing

The first non-empty line of `.claude/last-api-review.md` is **exactly** :

- `VERDICT: APPROVE` → exit loop, surface diff
- `VERDICT: REQUEST_CHANGES` → iter++, loop (cap 3)

No modifier (`VERDICT: APPROVE WITH CAVEATS` is not recognized and treated as APPROVE by default — but ideally the reviewer respects the strict format).

## Output

Streamed per-stage so you can watch progress. Each `/architect`, `/dev`, `/test`, `/review` reports its outcome.

Final report on APPROVE :

```
✅ Pipeline complete (semi-auto)
   Verdict:        APPROVE
   Iterations:     <N> (out of 3 max)
   Files modified: <N>
   Lines:          +<X> / -<Y>

   State files (gitignored, persist across sessions):
   - .claude/last-api-plan.md
   - .claude/last-api-dev-report.md
   - .claude/last-api-test-report.md
   - .claude/last-api-review.md

   Diff ready in working tree. Commit when satisfied:
     git diff
     git add <files>
     git commit -m "feat: <subject from plan>"
     git push -u origin feat/<branch>
```

Escalation on iter > 3 :

```
⚠️  ESCALATION — 3 REQUEST_CHANGES iterations exhausted
   Persistent issues at .claude/last-api-review.md
   Working tree left in current state. No commit.

   You can:
   - Inspect .claude/last-api-*.md for forensic
   - Fix manually + commit
   - Re-run /api-resource-pipeline if the issues are unrelated to what was attempted
```
