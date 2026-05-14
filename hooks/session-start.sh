#!/usr/bin/env bash

# ============================================
# gerard plugin — Session Start Hook
# Detects Symfony + API Platform 4.3 projects and configures environment
# ============================================

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
SKILL_DIR="${PLUGIN_ROOT}/skills/using-symfony-superpowers"

# Minimum supported versions
MIN_SYMFONY_MAJOR=7
MIN_SYMFONY_MINOR=4
MIN_API_PLATFORM_MAJOR=4
MIN_API_PLATFORM_MINOR=3

# ============================================
# 1. SYMFONY PROJECT DETECTION
# ============================================

detect_symfony_apps() {
  local search_root="${1:-.}"
  local apps=()

  while IFS= read -r -d '' composer_file; do
    if grep -q '"symfony/framework-bundle"' "$composer_file" 2>/dev/null; then
      local app_dir
      app_dir=$(dirname "$composer_file")
      apps+=("$app_dir")
    fi
  done < <(find "$search_root" \
    -name "composer.json" \
    -not -path "*/vendor/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -print0 2>/dev/null)

  if [[ ${#apps[@]} -gt 0 ]]; then
    printf '%s\n' "${apps[@]}"
  fi
}

# ============================================
# 2. ORCHESTRATION ROOT DETECTION
# ============================================
# Walk up from active_app to find the dir that owns the orchestration
# (Compose / DDEV / Make). For monorepos where composer.json lives in a
# sub-dir (e.g. samurai/symfony/) but compose.yaml + Makefile live at the
# repo root, this is the canonical place from which to run docker / make.

find_orchestration_root() {
  local app_dir="$1"
  local max_depth=4
  local current="$app_dir"
  local found=""

  for ((i=0; i<=max_depth; i++)); do
    if [[ -f "$current/Makefile" ]] \
      || [[ -f "$current/Makefile-solution" ]] \
      || [[ -f "$current/compose.yaml" ]] \
      || [[ -f "$current/compose.yml" ]] \
      || [[ -f "$current/docker-compose.yaml" ]] \
      || [[ -f "$current/docker-compose.yml" ]] \
      || [[ -d "$current/.ddev" ]]; then
      found="$current"
      break
    fi
    # Stop at filesystem root or at the repo root (.git directory)
    if [[ "$current" == "/" ]] || [[ -d "$current/.git" ]]; then
      if [[ -d "$current/.git" ]] && [[ -z "$found" ]]; then
        # If we hit .git without orchestration markers, still treat this as the root
        found="$current"
      fi
      break
    fi
    current=$(dirname "$current")
  done

  if [[ -z "$found" ]]; then
    found="$app_dir"
  fi
  echo "$found"
}

# ============================================
# 3. SYMFONY VERSION DETECTION
# ============================================

get_symfony_version() {
  local app_dir="$1"
  local version=""

  if [[ -f "$app_dir/composer.lock" ]]; then
    version=$(grep -A5 '"name": "symfony/framework-bundle"' "$app_dir/composer.lock" 2>/dev/null |
      grep '"version"' | head -1 |
      sed -E 's/.*"version": "v?([0-9]+\.[0-9]+).*/\1/')
  fi

  if [[ -z "$version" && -f "$app_dir/composer.json" ]]; then
    version=$(grep '"symfony/framework-bundle"' "$app_dir/composer.json" 2>/dev/null |
      sed -E 's/.*"[\^~]?([0-9]+\.[0-9]+).*/\1/')
  fi

  echo "${version:-unknown}"
}

# ============================================
# 4. API PLATFORM DETECTION (4.x split aware)
# ============================================

detect_api_platform() {
  local app_dir="$1"
  local has_api_platform="false"
  local api_version=""
  local package=""

  if [[ -f "$app_dir/composer.lock" ]]; then
    # API Platform 4.x split: api-platform/symfony + api-platform/doctrine-orm
    # API Platform 3.x / monolithic: api-platform/core
    for candidate in "api-platform/symfony" "api-platform/core"; do
      if grep -q "\"$candidate\"" "$app_dir/composer.lock" 2>/dev/null; then
        has_api_platform="true"
        package="$candidate"
        api_version=$(grep -A5 "\"name\": \"$candidate\"" "$app_dir/composer.lock" 2>/dev/null |
          grep '"version"' | head -1 |
          sed -E 's/.*"version": "v?([0-9]+\.[0-9]+).*/\1/')
        break
      fi
    done
  elif [[ -f "$app_dir/composer.json" ]]; then
    for candidate in "api-platform/symfony" "api-platform/core"; do
      if grep -q "\"$candidate\"" "$app_dir/composer.json" 2>/dev/null; then
        has_api_platform="true"
        package="$candidate"
        api_version=$(grep "\"$candidate\"" "$app_dir/composer.json" 2>/dev/null |
          sed -E 's/.*"[\^~]?([0-9]+\.[0-9]+).*/\1/')
        break
      fi
    done
  fi

  echo "${has_api_platform}:${api_version:-none}:${package:-none}"
}

# ============================================
# 5. VERSION COMPARISON HELPERS
# ============================================

# Returns 0 if version >= required, 1 otherwise. Args: actual_major actual_minor required_major required_minor
version_gte() {
  local am="$1" ami="$2" rm="$3" rmi="$4"
  if (( am > rm )); then return 0; fi
  if (( am < rm )); then return 1; fi
  if (( ami >= rmi )); then return 0; fi
  return 1
}

# ============================================
# 6. DOCKER TYPE DETECTION (at orchestration root)
# ============================================

detect_docker_type() {
  local root="$1"
  local docker_type="none"

  if [[ -d "$root/.ddev" ]]; then
    docker_type="ddev"
  elif [[ -f "$root/compose.yaml" ]]; then
    if grep -qE "(frankenphp|dunglas/symfony-docker|caddy)" "$root/compose.yaml" 2>/dev/null; then
      docker_type="symfony-docker"
    elif grep -q "services:" "$root/compose.yaml" 2>/dev/null; then
      docker_type="compose-yaml"
    fi
  elif [[ -f "$root/compose.yml" ]]; then
    if grep -qE "(frankenphp|dunglas/symfony-docker|caddy)" "$root/compose.yml" 2>/dev/null; then
      docker_type="symfony-docker"
    else
      docker_type="compose-yml"
    fi
  elif [[ -f "$root/docker-compose.yaml" ]]; then
    docker_type="docker-compose-yaml"
  elif [[ -f "$root/docker-compose.yml" ]]; then
    docker_type="docker-compose-yml"
  fi

  if [[ -d "$root/frankenphp" ]] || [[ -f "$root/Caddyfile" ]]; then
    docker_type="symfony-docker"
  fi

  echo "$docker_type"
}

# ============================================
# 7. MAKEFILE DETECTION (at orchestration root)
# ============================================
# Produces a colon-delimited tuple: present:primary:solution_file:is_boilerplate_smile:targets_csv

detect_makefile() {
  local root="$1"
  local present="false"
  local primary=""
  local solution_file=""
  local is_boilerplate_smile="false"
  local targets_csv=""

  if [[ -f "$root/Makefile" ]]; then
    present="true"
    primary="Makefile"
  elif [[ -f "$root/makefile" ]]; then
    present="true"
    primary="makefile"
  fi

  if [[ "$present" == "false" ]]; then
    echo "false:::false:"
    return
  fi

  # Solution file (Smile boilerplate convention — kept editable)
  if [[ -f "$root/Makefile-solution" ]]; then
    solution_file="Makefile-solution"
  elif [[ -f "$root/makefile-solution" ]]; then
    solution_file="makefile-solution"
  fi

  # Boilerplate Smile signature
  if [[ -f "$root/boilerplate_recipe.yml" ]] \
    || ( [[ -f "$root/conf/.env.global" ]] && grep -q "BOILERPLATE_VERSION" "$root/conf/.env.global" 2>/dev/null ); then
    is_boilerplate_smile="true"
  fi

  # Extract targets via `make -pRrq` (question mode, no execution)
  # Falls back gracefully if make is missing or the Makefile is broken.
  if command -v make &>/dev/null; then
    local raw_targets
    raw_targets=$(cd "$root" 2>/dev/null && make -pRrq -f "$primary" : 2>/dev/null \
      | awk '/^[a-zA-Z][a-zA-Z0-9_-]+:[^=]*$/ { sub(/:.*/, "", $1); print $1 }' \
      | grep -vE '^(Makefile|makefile|MAKEFILE|Makefile-solution|makefile-solution|\..*)$' \
      | sort -u \
      | tr '\n' ',' \
      | sed 's/,$//')
    targets_csv="$raw_targets"
  fi

  echo "${present}:${primary}:${solution_file}:${is_boilerplate_smile}:${targets_csv}"
}

# ============================================
# 8. DOCKER RUNNING STATUS (at orchestration root)
# ============================================

check_docker_running() {
  local root="$1"
  local docker_type="$2"

  if [[ "${SUPERPOWERS_TEST_DOCKER_RUNNING:-}" == "true" ]]; then
    echo "true"
    return
  fi
  if [[ "${SUPERPOWERS_TEST_DOCKER_RUNNING:-}" == "false" ]]; then
    echo "false"
    return
  fi

  if ! command -v docker &>/dev/null; then
    echo "false"
    return
  fi

  cd "$root" 2>/dev/null || {
    echo "false"
    return
  }

  if docker compose ps --filter "status=running" 2>/dev/null | grep -q .; then
    echo "true"
  else
    echo "false"
  fi
}

# ============================================
# 9. TEST FRAMEWORK DETECTION
# ============================================

detect_test_framework() {
  local app_dir="$1"
  local framework="phpunit"

  # composer.lock: only count pest if it's an installed package (name field),
  # not a suggestion of another package (which is the common false positive).
  if [[ -f "$app_dir/composer.lock" ]]; then
    if grep -q '"name": "pestphp/pest"' "$app_dir/composer.lock" 2>/dev/null; then
      framework="pest"
    fi
  elif [[ -f "$app_dir/composer.json" ]]; then
    # composer.json: scope the search to the require / require-dev blocks
    # (not the "suggest" block).
    if awk '
      /"require(-dev)?"\s*:\s*\{/ { in_req=1 }
      in_req && /\}/ { in_req=0 }
      in_req && /"pestphp\/pest"/ { found=1 }
      END { exit !found }
    ' "$app_dir/composer.json" 2>/dev/null; then
      framework="pest"
    fi
  fi

  echo "$framework"
}

# ============================================
# 10. DETERMINE RUNNER COMMANDS
# ============================================

# Check if `csv` contains target `t`. Args: targets_csv target_name
has_target() {
  local csv="$1"
  local t="$2"
  [[ ",${csv}," == *",${t},"* ]]
}

get_runner_commands() {
  local app_dir="$1"
  local root="$2"
  local docker_type="$3"
  local docker_running="$4"
  local makefile_present="$5"
  local makefile_targets="$6"

  local runner_type="host"
  local runner_cmd="php"
  local console_cmd="php bin/console"
  local composer_cmd="composer"
  local test_cmd="./vendor/bin/phpunit"
  local ci_cmd=""
  local quality_cmd=""
  local migrations_cmd=""

  # Priority 1: DDEV
  if [[ "$docker_type" == "ddev" ]]; then
    runner_type="ddev"
    runner_cmd="ddev exec"
    console_cmd="ddev exec bin/console"
    composer_cmd="ddev composer"
    test_cmd="ddev exec ./vendor/bin/phpunit"

  # Priority 2: Make (if Makefile has the canonical targets)
  elif [[ "$makefile_present" == "true" ]] \
    && ( has_target "$makefile_targets" "console" \
      || has_target "$makefile_targets" "tests" \
      || has_target "$makefile_targets" "test" \
      || has_target "$makefile_targets" "ci" ); then
    runner_type="make"
    runner_cmd="make"
    if has_target "$makefile_targets" "console"; then
      console_cmd="make console"
    fi
    if has_target "$makefile_targets" "composer"; then
      composer_cmd="make composer"
    fi
    if has_target "$makefile_targets" "tests"; then
      test_cmd="make tests"
    elif has_target "$makefile_targets" "test"; then
      test_cmd="make test"
    fi
    if has_target "$makefile_targets" "ci"; then
      ci_cmd="make ci"
    fi
    if has_target "$makefile_targets" "quality"; then
      quality_cmd="make quality"
    fi
    if has_target "$makefile_targets" "migrations"; then
      migrations_cmd="make migrations"
    fi

  # Priority 3: Symfony Docker (FrankenPHP)
  elif [[ "$docker_type" == "symfony-docker" && "$docker_running" == "true" ]]; then
    runner_type="symfony-docker"
    runner_cmd="docker compose exec php"
    console_cmd="docker compose exec php bin/console"
    composer_cmd="docker compose exec php composer"
    test_cmd="docker compose exec php ./vendor/bin/phpunit"

  # Priority 4: Generic Compose
  elif [[ "$docker_type" != "none" && "$docker_running" == "true" ]]; then
    runner_type="compose"
    local service_name="php"
    cd "$root" 2>/dev/null || true
    if docker compose config --services 2>/dev/null | grep -q "^app$"; then
      service_name="app"
    fi
    runner_cmd="docker compose exec $service_name"
    console_cmd="docker compose exec $service_name bin/console"
    composer_cmd="docker compose exec $service_name composer"
    test_cmd="docker compose exec $service_name ./vendor/bin/phpunit"
  fi

  # Pipe-separated tuple
  echo "${runner_type}|${runner_cmd}|${console_cmd}|${composer_cmd}|${test_cmd}|${ci_cmd}|${quality_cmd}|${migrations_cmd}"
}

# ============================================
# MAIN EXECUTION
# ============================================

main() {
  local cwd="${PWD}"
  local apps

  mapfile -t apps < <(detect_symfony_apps "$cwd")

  if [[ ${#apps[@]} -eq 0 ]]; then
    exit 0
  fi

  local active_app=""
  for app in "${apps[@]}"; do
    if [[ "$cwd" == "$app"* ]]; then
      active_app="$app"
      break
    fi
  done
  [[ -z "$active_app" ]] && active_app="${apps[0]}"

  local orchestration_root
  orchestration_root=$(find_orchestration_root "$active_app")

  local active_app_relative=""
  if [[ "$active_app" != "$orchestration_root" ]]; then
    active_app_relative="${active_app#$orchestration_root/}"
  fi

  local symfony_version api_platform_info docker_type docker_running test_framework runner_info makefile_info
  symfony_version=$(get_symfony_version "$active_app")
  api_platform_info=$(detect_api_platform "$active_app")
  docker_type=$(detect_docker_type "$orchestration_root")
  docker_running=$(check_docker_running "$orchestration_root" "$docker_type")
  test_framework=$(detect_test_framework "$active_app")
  makefile_info=$(detect_makefile "$orchestration_root")

  # Parse API Platform info
  IFS=':' read -r has_api_platform api_version api_package <<<"$api_platform_info"

  # Parse Makefile info (5 fields, targets_csv is last and may contain commas)
  local makefile_present makefile_primary makefile_solution makefile_is_smile makefile_targets
  makefile_present=$(echo "$makefile_info" | cut -d: -f1)
  makefile_primary=$(echo "$makefile_info" | cut -d: -f2)
  makefile_solution=$(echo "$makefile_info" | cut -d: -f3)
  makefile_is_smile=$(echo "$makefile_info" | cut -d: -f4)
  makefile_targets=$(echo "$makefile_info" | cut -d: -f5-)

  runner_info=$(get_runner_commands "$active_app" "$orchestration_root" "$docker_type" "$docker_running" "$makefile_present" "$makefile_targets")
  IFS='|' read -r runner_type runner_cmd console_cmd composer_cmd test_cmd ci_cmd quality_cmd migrations_cmd <<<"$runner_info"

  # ============================================
  # VERSION WARNINGS (Symfony < 7.4, API Platform < 4.3)
  # ============================================

  local warnings=()

  # Symfony version check
  local symfony_supported="false"
  if [[ "$symfony_version" != "unknown" ]]; then
    local sf_major sf_minor
    sf_major=$(echo "$symfony_version" | cut -d. -f1)
    sf_minor=$(echo "$symfony_version" | cut -d. -f2)
    if version_gte "$sf_major" "$sf_minor" "$MIN_SYMFONY_MAJOR" "$MIN_SYMFONY_MINOR"; then
      symfony_supported="true"
    else
      warnings+=("Symfony $symfony_version detected. This plugin targets Symfony ${MIN_SYMFONY_MAJOR}.${MIN_SYMFONY_MINOR} LTS+ — older versions are out of scope.")
    fi
  fi

  # API Platform version check
  local api_platform_supported="false"
  if [[ "$has_api_platform" == "true" && "$api_version" != "none" ]]; then
    local ap_major ap_minor
    ap_major=$(echo "$api_version" | cut -d. -f1)
    ap_minor=$(echo "$api_version" | cut -d. -f2)
    if version_gte "$ap_major" "$ap_minor" "$MIN_API_PLATFORM_MAJOR" "$MIN_API_PLATFORM_MINOR"; then
      api_platform_supported="true"
    else
      warnings+=("API Platform $api_version detected. This plugin targets ${MIN_API_PLATFORM_MAJOR}.${MIN_API_PLATFORM_MINOR}+ — see skill 'gerard:api-platform-upgrade' to migrate.")
    fi
    # Detect monolithic 3.x package
    if [[ "$api_package" == "api-platform/core" && "$ap_major" -ge 4 ]]; then
      :
    elif [[ "$api_package" == "api-platform/core" ]]; then
      warnings+=("Legacy package 'api-platform/core' detected. In 4.x it splits into 'api-platform/symfony' + 'api-platform/doctrine-orm'.")
    fi
  fi

  # Docker guidance
  local guidance_docker=""
  if [[ "$docker_type" == "ddev" && "$docker_running" == "false" ]]; then
    guidance_docker="Start DDEV with: ddev start"
  elif [[ "$runner_type" == "make" && "$docker_running" == "false" ]]; then
    if has_target "$makefile_targets" "up"; then
      guidance_docker="Start services with: make up"
    else
      guidance_docker="Start services first (no 'make up' target found — check Makefile)"
    fi
  elif [[ "$docker_type" == "symfony-docker" && "$docker_running" == "false" ]]; then
    guidance_docker="Start Symfony Docker with: docker compose up -d --wait"
  elif [[ "$docker_type" != "none" && "$docker_type" != "symfony-docker" && "$docker_type" != "ddev" && "$docker_running" == "false" ]]; then
    guidance_docker="Start Docker containers with: docker compose up -d"
  fi

  # Makefile-solution guidance
  if [[ "$makefile_present" == "true" && -n "$makefile_solution" ]]; then
    warnings+=("Project uses the Makefile-solution convention. Add custom targets to '$makefile_solution', never to '$makefile_primary' (framework file).")
  fi

  # Build JSON-safe warnings array
  local warnings_json="[]"
  if [[ ${#warnings[@]} -gt 0 ]]; then
    warnings_json="["
    local first=true
    for w in "${warnings[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        warnings_json+=","
      fi
      # Escape double quotes inside the warning
      local escaped=${w//\"/\\\"}
      warnings_json+="\"$escaped\""
    done
    warnings_json+="]"
  fi

  # Build targets JSON array from CSV
  local targets_json="[]"
  if [[ -n "$makefile_targets" ]]; then
    targets_json="["
    local first=true
    IFS=',' read -ra tarr <<<"$makefile_targets"
    for t in "${tarr[@]}"; do
      [[ -z "$t" ]] && continue
      if [[ "$first" == "true" ]]; then
        first=false
      else
        targets_json+=","
      fi
      targets_json+="\"$t\""
    done
    targets_json+="]"
  fi

  # Optional command fields (only emit if non-empty)
  local cmd_ci_json="null"
  [[ -n "$ci_cmd" ]] && cmd_ci_json="\"$ci_cmd\""
  local cmd_quality_json="null"
  [[ -n "$quality_cmd" ]] && cmd_quality_json="\"$quality_cmd\""
  local cmd_migrations_json="null"
  [[ -n "$migrations_cmd" ]] && cmd_migrations_json="\"$migrations_cmd\""

  # Optional Makefile fields
  local makefile_solution_json="null"
  [[ -n "$makefile_solution" ]] && makefile_solution_json="\"$makefile_solution\""
  local makefile_primary_json="null"
  [[ -n "$makefile_primary" ]] && makefile_primary_json="\"$makefile_primary\""

  cat <<EOF
{
  "plugin": "superpowers-api-platform",
  "detected_apps": ${#apps[@]},
  "active_app": "$active_app",
  "orchestration_root": "$orchestration_root",
  "active_app_relative": "$active_app_relative",
  "symfony": {
    "version": "$symfony_version",
    "is_lts_7_4_or_higher": $symfony_supported
  },
  "api_platform": {
    "installed": $has_api_platform,
    "version": "$api_version",
    "package": "$api_package",
    "is_4_3_or_higher": $api_platform_supported
  },
  "docker": {
    "type": "$docker_type",
    "running": $docker_running,
    "is_symfony_docker": $(if [[ "$docker_type" == "symfony-docker" ]]; then echo "true"; else echo "false"; fi)
  },
  "makefile": {
    "present": $makefile_present,
    "primary": $makefile_primary_json,
    "solution_file": $makefile_solution_json,
    "is_boilerplate_smile": $makefile_is_smile,
    "targets": $targets_json
  },
  "test_framework": "$test_framework",
  "commands": {
    "runner_type": "$runner_type",
    "runner": "$runner_cmd",
    "console": "$console_cmd",
    "composer": "$composer_cmd",
    "test": "$test_cmd",
    "ci": $cmd_ci_json,
    "quality": $cmd_quality_json,
    "migrations": $cmd_migrations_json
  },
  "guidance": $(if [[ -n "$guidance_docker" ]]; then echo "\"$guidance_docker\""; else echo "null"; fi),
  "warnings": $warnings_json
}
EOF

}

main "$@"
