#!/usr/bin/env bash

# ============================================
# gerard plugin — PostToolUse Hook
# After Write/Edit/MultiEdit on a .php file: run a fast regex pass for high-
# signal anti-patterns, then run phpstan (if available, 30s timeout). The
# implementer gets immediate feedback so the gatekeeper round-trip is shorter.
#
# Scope is intentionally narrow — the gatekeeper performs the full 39-rule
# adversarial review. This hook catches only the obvious things a regex can
# match reliably with no false positives.
# ============================================

set -euo pipefail

payload=$(cat || true)
if [[ -z "$payload" ]] || ! command -v jq &>/dev/null; then
  exit 0
fi

tool_name=$(echo "$payload" | jq -r '.tool_name // empty')
file_path=$(echo "$payload" | jq -r '.tool_input.file_path // empty')

case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
  exit 0
fi
if [[ "$file_path" != *.php ]]; then
  exit 0
fi

# ============================================
# Regex anti-pattern scan
# Each line: <regex>|<short reason>
# Regexes are PCRE-compatible; we use grep -nE for portability.
# Keep this list tight — false positives erode trust in the hook.
# ============================================
findings=()
scan_pattern() {
  local pattern="$1"
  local reason="$2"
  local hits
  hits=$(grep -nE "$pattern" "$file_path" 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    while IFS= read -r line; do
      findings+=("$reason — $line")
    done <<<"$hits"
  fi
}

# Debug & dev artefacts left in the source
scan_pattern '^[[:space:]]*(dd|dump|var_dump|var_export|print_r)[[:space:]]*\(' \
  'debug call must not ship'

# Symfony 7.4+ / API Platform 4.3 hygiene
scan_pattern '//[[:space:]]*(TODO|FIXME|XXX)\b' \
  'TODO/FIXME forbidden (Symfony 7.4+ rule)'
scan_pattern ':[[:space:]]*mixed([[:space:]]|$|\{)' \
  '`mixed` return type forbidden — narrow the signature'
scan_pattern '@ApiPlatform\\' \
  'legacy 3.x annotation — migrate to PHP attributes'
scan_pattern '#\[ApiResource\b[^]]*operations[[:space:]]*:[[:space:]]*\[\s*new Get\(\)[[:space:]]*,\s*new GetCollection\(\)[[:space:]]*\]' \
  'manual operations: [] when defaults would suffice'

# Hard-coded environment smell (false positives are low — env vars belong in .env)
scan_pattern 'https?://(localhost|127\.0\.0\.1)' \
  'hard-coded localhost URL — move to .env'

if [[ ${#findings[@]} -gt 0 ]]; then
  reason="gerard post-tool-use regex scan found anti-patterns in ${file_path}:\n"
  for f in "${findings[@]}"; do
    reason+="  - ${f}\n"
  done
  reason+="\nFix these before continuing. The gatekeeper will block on these rules anyway — better to catch them now."
  jq -n --arg r "$(printf '%b' "$reason")" '{
    decision: "block",
    reason: $r
  }'
  exit 0
fi

# ============================================
# phpstan (best-effort, 30s timeout)
# Walk up from the file to find a phpstan binary or a runner. Skip silently
# if nothing is available — the gatekeeper will still catch type errors.
# ============================================

find_phpstan_runner() {
  local dir
  dir=$(dirname -- "$file_path")
  local depth=0
  while [[ "$dir" != "/" && $depth -lt 8 ]]; do
    if [[ -x "$dir/vendor/bin/phpstan" ]]; then
      echo "$dir/vendor/bin/phpstan"
      return 0
    fi
    if [[ -d "$dir/.ddev" ]]; then
      echo "ddev:$dir"
      return 0
    fi
    dir=$(dirname -- "$dir")
    depth=$((depth + 1))
  done
  return 1
}

if ! command -v timeout &>/dev/null; then
  exit 0
fi

runner=$(find_phpstan_runner || true)
if [[ -z "$runner" ]]; then
  exit 0
fi

phpstan_output=""
phpstan_exit=0
case "$runner" in
  ddev:*)
    ddev_root="${runner#ddev:}"
    rel="${file_path#${ddev_root}/}"
    phpstan_output=$(timeout 30 ddev exec phpstan analyse "$rel" --no-progress --error-format=raw 2>&1) || phpstan_exit=$?
    ;;
  *)
    phpstan_output=$(timeout 30 "$runner" analyse "$file_path" --no-progress --error-format=raw 2>&1) || phpstan_exit=$?
    ;;
esac

# timeout exit 124 = ran out of time; treat as soft-skip
if [[ $phpstan_exit -eq 124 ]]; then
  exit 0
fi

# phpstan exits non-zero when errors are found. Only block when there is real output.
if [[ $phpstan_exit -ne 0 && -n "$phpstan_output" ]]; then
  reason="phpstan flagged ${file_path}:\n${phpstan_output}\n\nFix before continuing."
  jq -n --arg r "$reason" '{
    decision: "block",
    reason: $r
  }'
  exit 0
fi

exit 0
