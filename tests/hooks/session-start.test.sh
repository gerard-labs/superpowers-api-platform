#!/usr/bin/env bash

# ============================================
# Test harness for hooks/session-start.sh
# Runs the hook against each fixture and validates the JSON output.
# ============================================

set -uo pipefail

PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
HOOK="${PLUGIN_ROOT}/hooks/session-start.sh"
FIXTURES_DIR="${PLUGIN_ROOT}/tests/fixtures"

# Force docker.running=false so tests are deterministic regardless of host state
export SUPERPOWERS_TEST_DOCKER_RUNNING=false

PASS=0
FAIL=0
FAILED_TESTS=()

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    green "  PASS  $name: $actual"
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$name: expected '$expected', got '$actual'")
    red   "  FAIL  $name: expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    green "  PASS  $name: contains '$needle'"
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$name: '$haystack' missing '$needle'")
    red   "  FAIL  $name: missing '$needle' in '$haystack'"
  fi
}

run_fixture() {
  local name="$1" fixture_dir="$2" expected_runner="$3" expected_console="$4" expected_relative="$5"

  yellow ""
  yellow "▶ Fixture: $name ($fixture_dir)"

  local output
  output=$(cd "$fixture_dir" && bash "$HOOK" 2>&1)

  if ! echo "$output" | jq . > /dev/null 2>&1; then
    red "  FAIL  Hook did not produce valid JSON"
    red   "$output"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$name: invalid JSON output")
    return
  fi

  local runner_type console_cmd active_relative makefile_present
  runner_type=$(echo "$output" | jq -r '.commands.runner_type')
  console_cmd=$(echo "$output" | jq -r '.commands.console')
  active_relative=$(echo "$output" | jq -r '.active_app_relative')
  makefile_present=$(echo "$output" | jq -r '.makefile.present')

  assert_eq "$name › runner_type"          "$expected_runner"   "$runner_type"
  assert_eq "$name › console"              "$expected_console"  "$console_cmd"
  assert_eq "$name › active_app_relative"  "$expected_relative" "$active_relative"
  assert_eq "$name › makefile.present"     "true"               "$makefile_present"
}

# ─────────────────────────────────────────────
# Fixture 1: monorepo-make-symfony
# Symfony in symfony/, Makefile + compose at root.
# ─────────────────────────────────────────────
run_fixture \
  "monorepo-make-symfony" \
  "$FIXTURES_DIR/monorepo-make-symfony" \
  "make" \
  "make console" \
  "symfony"

# Detailed assertions
output_1=$(cd "$FIXTURES_DIR/monorepo-make-symfony" && bash "$HOOK" 2>&1)
targets_1=$(echo "$output_1" | jq -r '.makefile.targets | join(",")')
assert_contains "monorepo › targets contains console"    "console"     "$targets_1"
assert_contains "monorepo › targets contains tests"      "tests"       "$targets_1"
assert_contains "monorepo › targets contains ci"         "ci"          "$targets_1"
assert_contains "monorepo › targets contains migrations" "migrations"  "$targets_1"

is_smile_1=$(echo "$output_1" | jq -r '.makefile.is_boilerplate_smile')
assert_eq "monorepo › is_boilerplate_smile" "false" "$is_smile_1"

solution_1=$(echo "$output_1" | jq -r '.makefile.solution_file')
assert_eq "monorepo › solution_file" "null" "$solution_1"

# ─────────────────────────────────────────────
# Fixture 2: smile-boilerplate
# Full Smile-style: Makefile + Makefile-solution + boilerplate_recipe.yml + conf/.env.global
# ─────────────────────────────────────────────
run_fixture \
  "smile-boilerplate" \
  "$FIXTURES_DIR/smile-boilerplate" \
  "make" \
  "make console" \
  "symfony"

output_2=$(cd "$FIXTURES_DIR/smile-boilerplate" && bash "$HOOK" 2>&1)
is_smile_2=$(echo "$output_2" | jq -r '.makefile.is_boilerplate_smile')
assert_eq "smile › is_boilerplate_smile" "true" "$is_smile_2"

solution_2=$(echo "$output_2" | jq -r '.makefile.solution_file')
assert_eq "smile › solution_file" "Makefile-solution" "$solution_2"

# Warning must mention the Makefile-solution convention
warnings_2=$(echo "$output_2" | jq -r '.warnings | join(" || ")')
assert_contains "smile › warning mentions Makefile-solution" "Makefile-solution" "$warnings_2"

# Commands surface
ci_2=$(echo "$output_2" | jq -r '.commands.ci')
quality_2=$(echo "$output_2" | jq -r '.commands.quality')
migrations_2=$(echo "$output_2" | jq -r '.commands.migrations')
assert_eq "smile › commands.ci"         "make ci"         "$ci_2"
assert_eq "smile › commands.quality"    "make quality"    "$quality_2"
assert_eq "smile › commands.migrations" "make migrations" "$migrations_2"

# ─────────────────────────────────────────────
# Fixture 3: flat-make
# Single dir with composer.json + Makefile + compose.yaml (FrankenPHP).
# Make priority should still win.
# ─────────────────────────────────────────────
run_fixture \
  "flat-make" \
  "$FIXTURES_DIR/flat-make" \
  "make" \
  "make console" \
  ""

output_3=$(cd "$FIXTURES_DIR/flat-make" && bash "$HOOK" 2>&1)
docker_type_3=$(echo "$output_3" | jq -r '.docker.type')
assert_eq "flat-make › docker.type (FrankenPHP signal)" "symfony-docker" "$docker_type_3"
# Make should still win over symfony-docker because targets are present
runner_3=$(echo "$output_3" | jq -r '.commands.runner_type')
assert_eq "flat-make › Make wins over Symfony Docker" "make" "$runner_3"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  red "Failures:"
  for t in "${FAILED_TESTS[@]}"; do
    red "  - $t"
  done
  exit 1
fi

green "All hook fixture tests passed."
exit 0
