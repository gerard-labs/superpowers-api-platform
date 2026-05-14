#!/usr/bin/env bash

# ============================================
# gerard plugin — PreToolUse Hook
# Blocks Write/Edit/MultiEdit on secret file patterns. Stops Claude from
# accidentally serializing credentials, keys, or certs into a commit.
# ============================================

set -euo pipefail

payload=$(cat || true)
if [[ -z "$payload" ]] || ! command -v jq &>/dev/null; then
  exit 0
fi

tool_name=$(echo "$payload" | jq -r '.tool_name // empty')
file_path=$(echo "$payload" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

basename=$(basename -- "$file_path")

# Secret file patterns (basename match). Keep this list narrow — false positives
# block real edits and frustrate the user.
case "$basename" in
  .env|.env.*|*.pem|*.key|*.p12|*.pfx|*credentials*|*.crt|id_rsa|id_ed25519|id_ecdsa|*.kdbx)
    reason="gerard pre-tool-use blocked write to ${file_path}: filename matches a secret pattern (.env*, *.pem, *.key, *.p12, *.pfx, *credentials*, *.crt, ssh keys, *.kdbx). If you truly need to edit this, ask the user to do it manually."
    jq -n --arg r "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $r
      }
    }'
    exit 0
    ;;
esac

exit 0
