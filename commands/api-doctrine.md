---
description: Export / import / list versionable snapshots of the three agents' memory directories. M3 hybrid strategy (decision A in the plan).
argument-hint: "export <name> | import <name> | list"
allowed-tools: Bash, Read, Write, Glob, Grep
---

# /api-doctrine — memory snapshots

Auto-memory is volatile by default (each agent's `memory/` dir is owned by the agent, evolves per-session). When a team wants to share or version a calibrated state — "the doctrine we agreed on for project X" — this command exports the three memory dirs into a single markdown file the team can commit alongside the code.

Decision A (`docs/v1.0-plan.md` section 1): M3 hybrid. Volatile native by default, opt-in snapshots for versioning.

Snapshots live under `.claude/memory-snapshots/<name>.md`. They are NOT auto-loaded; users must `/api-doctrine import <name>` explicitly.

---

## Parse args

User input: `$ARGUMENTS`

Expected forms:
- `export <name>`
- `import <name>`
- `list`

`<name>` must be kebab-case, no spaces, no path separators. Validate before doing anything. If invalid: STOP and explain.

If the user typed something else (e.g. just `/api-doctrine`): print usage and exit.

---

## Subcommand: list

!ls .claude/memory-snapshots/ 2>/dev/null | sort || echo "no_snapshots_dir"

Output as a numbered list with file sizes and last-modified dates. If the dir doesn't exist or is empty: report `No snapshots found. Use /api-doctrine export <name> to create one.`

---

## Subcommand: export <name>

1. Ensure `.claude/memory-snapshots/` exists. Create it if not (`mkdir -p`).

2. If `.claude/memory-snapshots/<name>.md` already exists: ask the user to confirm overwrite. Default = abort.

3. Collect content from the three agent memory dirs:
   - `agents/api-architect-trio/memory/*.md`
   - `agents/api-implementer/memory/*.md`
   - `agents/gerard-gatekeeper/memory/*.md`

   Skip `.gitkeep` and any empty files.

4. Compose the snapshot markdown. Layout:

```markdown
---
name: <name>
created: <ISO 8601 timestamp>
generated-by: gerard /api-doctrine export
plugin-version: 1.0.0
---

# Doctrine snapshot — <name>

This file is a snapshot of the three agent memory directories taken at the time above. Import it back into a session with `/api-doctrine import <name>` to re-populate the agent memory dirs with the same calibration.

## agents/api-architect-trio/memory

<concatenation of each memory file, each one wrapped in:>

### <filename without extension>
<file content verbatim>

---

## agents/api-implementer/memory
<same pattern>

---

## agents/gerard-gatekeeper/memory
<same pattern>
```

5. Write the file with `Write` tool. Print a confirmation line:
   > `gerard: snapshot exported to .claude/memory-snapshots/<name>.md. Commit it to share with the team.`

6. Suggest the next git step: `git add .claude/memory-snapshots/<name>.md && git commit -m "doctrine: snapshot <name>"`.

---

## Subcommand: import <name>

1. Read `.claude/memory-snapshots/<name>.md`. If absent: STOP, suggest `/api-doctrine list`.

2. Parse the three sections (`## agents/api-architect-trio/memory`, etc.). For each subsection (`### <filename>`):
   - Reconstruct the original file path: `agents/<agent>/memory/<filename>.md`
   - Check if the target file already exists. If yes: append `-imported-<timestamp>` to the new name to avoid clobbering live state.
   - Write the content with `Write` tool.

3. Print a summary table: rows = `<agent>/<file>`, status = `new` | `renamed-to-avoid-clobber`. Total = N files written.

4. Tell the user: "Snapshot imported. Active for this session — next time the agents read their memory dirs they'll pick up the imported entries."

---

## Safety rails

- Never read or write outside `agents/*/memory/` or `.claude/memory-snapshots/`.
- Never commit anything from this command. Snapshot export prints a `git add` suggestion but does not run it (decision: separate inspection point).
- Never auto-import on session start. Imports are always explicit and user-initiated.
- If a memory file contains anything that looks like a secret (matches the pre-tool-use patterns), refuse to include it in the snapshot and tell the user which file to clean up.
