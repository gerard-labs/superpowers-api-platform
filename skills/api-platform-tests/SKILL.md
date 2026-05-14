---
name: api-platform-tests
description: Write production-grade API Platform 4.3 functional tests with `ApiTestCase` — Foundry factories + `ResetDatabase`, DAMA Doctrine test bundle (transaction-rollback per test), ParaTest for parallel execution, lightweight md5 password hashing in test env, reusable authenticated client (`createClientWithCredentials`), `disableReboot()` for multi-request flows, `findIriBy()`, schema assertions (`assertMatchesResourceItemJsonSchema`, `assertMatchesResourceCollectionJsonSchema`, `assertMatchesJsonSchema`), the 4.x JSON-LD shape (`member`, `totalItems`, `view`, `next` — no `hydra:` prefix), and the **exhaustive failure-mode catalog** every write operation must cover (422 invalid payload, 401 anonymous, 403 wrong role, 404 unknown id, 405 wrong verb, 409 unique-constraint clash, 415 wrong Content-Type, MaxDepth circular serialization, async retry / DLQ). Trigger when writing or reviewing API tests, hitting "expected hydra:member but found member", debugging slow suites, setting up CI test pipelines, adopting scenario-based test naming, or auditing negative-path coverage ("missing 422 test", "no 401 assertion", "failure modes").
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Functional tests

## Use when
- Writing API tests for a new resource / operation.
- Updating older tests still using `hydra:member` / `hydra:totalItems` (broken in 4.x).
- Speeding up a slow suite (Foundry → DAMA → ParaTest progression).
- Authenticating clients with JWT for protected endpoints.
- Asserting the JSON-LD schema strictly.

## Default workflow
1. Install the dev stack — `symfony/test-pack`, `http-client`, `browser-kit`, `justinrainbow/json-schema`, `dama/doctrine-test-bundle`, `zenstruck/foundry`, `brianium/paratest`.
2. Wire DAMA via the PHPUnit extension; configure md5 hashing in `config/packages/test/security.yaml`.
3. Write tests extending `ApiTestCase` with `Factories` + `ResetDatabase` traits.
4. Cover happy path, 401, 403, 404, 422, ownership, filters, pagination on every operation.
5. Run with `./vendor/bin/paratest -p8` in CI for parallel execution.

## Guardrails
- **No `hydra:` prefix** anywhere in assertions in 4.x. Use `member`, `totalItems`, `view`, `next`.
- **Default page size is 30 in 4.x** (not 20 like 3.x). Adapt counts.
- **Hash algorithm `md5` is for tests only.** Never in any other env.
- **One assertion per scenario.** No conditional logic in tests.
- **Tests are independent** — DAMA transaction rollback or Foundry `ResetDatabase` ensures it; never rely on order.

## Progressive disclosure
- `SKILL.md` lists posture and rules.
- `reference.md` carries the full stack setup, the reusable authenticated client, JWT auth tests, schema assertions, filters + pagination + auth + ownership coverage matrix, scenario-based naming, CI patterns.

## Output contract
- Tests in `tests/Functional/Api/` extending `ApiTestCase` (or a project-specific `AbstractApiTest`).
- Each operation covered with happy path + at least one negative case (401/403/404/422).
- Schema assertions on collection and item responses.
- CI invokes `./vendor/bin/paratest -p8`.

## References
- `reference.md`
