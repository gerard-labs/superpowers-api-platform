#!/usr/bin/env bash

# ============================================
# gerard plugin — UserPromptSubmit Hook
# When the user prompt starts with /api, parse keywords and inject a
# system-reminder telling Claude which skills are relevant to pre-fetch.
# Silent (exit 0, no stdout) on all other prompts.
# ============================================

set -euo pipefail

# Read the stdin JSON payload. Claude Code sends:
#   { "hook_event_name": "UserPromptSubmit", "prompt": "<text>", ... }
payload=$(cat || true)

# Extract the prompt text. If jq is missing or payload is empty, exit silent.
if [[ -z "$payload" ]] || ! command -v jq &>/dev/null; then
  exit 0
fi

prompt=$(echo "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)
if [[ -z "$prompt" ]]; then
  exit 0
fi

# Only fire when the user prompt starts with /api (with optional leading whitespace).
# Matches: /api, /api-finalize, /api-doctrine. We narrow to /api  + story args.
if ! [[ "$prompt" =~ ^[[:space:]]*/api([[:space:]]|$) ]]; then
  exit 0
fi

# Lower-case the prompt for case-insensitive keyword matching.
lc=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# Keyword → skill mapping. Order is significant — more specific matches first.
# Each line: <regex>|<skill-slug>
mapping=$(cat <<'EOF'
filter|search|sort|order|api-platform-filters
paginat|page size|cursor|api-platform-pagination
mcp|model context protocol|api-platform-mcp
upload|multipart|file storage|attachment|api-platform-file-upload
security|jwt|oidc|cors|voter|auth|api-platform-security
serializ|normaliz|groups|api-platform-serialization
state processor|processor|api-platform-state-processors
state provider|provider|api-platform-state-providers
openapi|swagger|doc generation|api-platform-openapi
mutator|patch|api-platform-mutators
resilien|retry|circuit breaker|api-platform-resilience
performance|n\+1|cache|api-platform-performance
identifier|ulid|uuid|api-platform-identifiers
version|deprecation|api-platform-versioning
error|exception|problem\+json|api-platform-errors
dto|api-platform-dto-resources
upgrade|migration to 4|api-platform-upgrade
user resource|user entity|api-platform-user
test|pest|phpunit|api-platform-tests
functional test|kernelbrowser|functional-tests
migration|doctrine-migrations
transaction|doctrine-transactions
fetch mode|lazy|eager|doctrine-fetch-modes
fixture|foundry|doctrine-fixtures-foundry
relation|onetomany|manytoone|doctrine-relations
batch|doctrine-batch-processing
messenger|async|symfony-messenger
scheduler|cron|symfony-scheduler
cache|symfony-cache
voter|symfony-voters
rate limit|throttle|rate-limiting
cqrs|command handler|query handler|cqrs-and-handlers
value object|vo |dto |value-objects-and-dtos
port|adapter|hexagonal|ports-and-adapters
strategy pattern|strategy-pattern
controller|controller-cleanup
makefile|make target|makefile-discipline
runner|ddev|docker compose|runner-selection
EOF
)

suggested=()
while IFS='|' read -r -a fields; do
  # The skill slug is the last field; everything before is alternation patterns.
  n=${#fields[@]}
  [[ $n -lt 2 ]] && continue
  skill="${fields[$((n-1))]}"
  for ((i=0; i<n-1; i++)); do
    pattern="${fields[$i]}"
    [[ -z "$pattern" ]] && continue
    if [[ "$lc" =~ $pattern ]]; then
      suggested+=("$skill")
      break
    fi
  done
done <<<"$mapping"

# Dedupe while preserving order
if [[ ${#suggested[@]} -eq 0 ]]; then
  exit 0
fi

declare -A seen
ordered=()
for s in "${suggested[@]}"; do
  if [[ -z "${seen[$s]:-}" ]]; then
    seen[$s]=1
    ordered+=("$s")
  fi
done

# Build the additionalContext string Claude Code will inject as a system reminder.
lines=""
for s in "${ordered[@]}"; do
  lines+="- gerard:${s}\n"
done

context=$(printf 'Hook hint — prompt keywords suggest these gerard skills are likely relevant for this /api run. Read their SKILL.md before dispatching workers if applicable:\n%b' "$lines")

# Emit the official Claude Code hook response. additionalContext is appended to
# the conversation as a system reminder before the user prompt is processed.
jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
