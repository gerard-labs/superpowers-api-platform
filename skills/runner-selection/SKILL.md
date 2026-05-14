---
name: runner-selection
description: Detect the correct command runner for the project — DDEV (`.ddev/`), Make (Makefile with `console`/`tests`/`ci` targets — covers Smile/agency boilerplates where Symfony lives in a sub-dir and Make wraps Docker), Symfony Docker/FrankenPHP (`compose.yaml` with `frankenphp`/`caddy`), generic Docker Compose, or host. Build the right prefix for `bin/console` / `composer` / `phpunit` / `paratest`. Handles monorepos by walking up from `composer.json` to find the orchestration root (Makefile/compose.yaml). The session-start hook does this automatically; this skill documents the manual detection logic and the fallback when the hook hasn't run.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Runner Selection (Symfony)

## Use when
- The session-start hook output is unavailable (manual `claude` invocation, fresh repo).
- You need to verify which runner the hook picked.
- A command works locally but fails because the host environment differs from Docker.
- The project uses a Makefile-driven workflow (`make console`, `make tests`) and you need to know which target to call.

## Default workflow
1. From `composer.json` (the active app), walk **up** to the orchestration root — the first parent dir with a `Makefile`, `Makefile-solution`, `compose.yaml`, `compose.yml`, `docker-compose.yml`, `docker-compose.yaml`, or `.ddev/`. Stop at `.git/`.
2. At that root, detect in this priority order:
   - `.ddev/` → **DDEV**
   - `Makefile` with `console` / `tests` / `ci` targets → **Make** (most common in agency boilerplates)
   - `compose.yaml` mentioning `frankenphp` / `dunglas/symfony-docker` / `caddy` → **Symfony Docker**
   - Any other compose file → **generic Compose**
   - Otherwise → **host**
3. Build the prefix from the prefix table in `reference.md`.
4. For Make projects, **prefer `make <target>` over the raw Docker invocation** — the target already wraps the right `docker compose run --rm` or `exec` call with the right `COMPOSE_FILE` and env files.

## Guardrails
- Always **detect** before running; never assume host.
- A `compose.yaml` present **but no service running** ≠ host. Suggest `make up` (if Make), `ddev start` (if DDEV), or `docker compose up -d` (otherwise).
- For multi-service compose (`php` + `database` + `redis`), the relevant service is usually `php` or `app`. Inspect `docker compose config --services`.
- For Make projects with a `Makefile-solution` file, **never** add new targets to `Makefile` (framework file, regenerated from the boilerplate). Add to `Makefile-solution` instead — see skill `gerard:makefile-discipline`.

## Progressive disclosure
- This file covers the detection logic.
- `reference.md` covers the full prefix table per runner, Make convention, monorepo walking, and edge cases.

## Output contract
- A working `bin/console` / `composer` / `phpunit` invocation.
- A note in the dev report saying which runner was used (so the reviewer can verify).

## References
- `reference.md`
- `docs/complexity-tiers.md`
- `hooks/session-start.sh` — the canonical detection (host mode duplicates this logic for manual cases)
- `gerard:makefile-discipline` — sister skill for projects driven by `make`
