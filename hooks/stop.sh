#!/usr/bin/env bash

# ============================================
# gerard plugin — Stop Hook
# Minimal scope (decision #11): emit a terminal notification when Claude
# stops, hinting at the next step (/api-finalize). Anti-pattern scans live in
# the gatekeeper, not here, to avoid false positives during legitimate work.
# ============================================

set -euo pipefail

cat >/dev/null 2>&1 || true

branch="current branch"
if command -v git &>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
fi

msg="gerard: goal cleared on ${branch}. Run /api-finalize to commit + PR."
seq=$(printf '\a\033]9;%s\a' "$msg")

jq -n --arg s "$seq" '{ terminalSequence: $s }' 2>/dev/null || exit 0
