---
name: functional-tests
description: Write Symfony functional tests for non-API HTTP endpoints (server-rendered pages, form submissions, redirects, auth flows) with `WebTestCase` + `BrowserKit` + `DomCrawler` + Foundry — drives RED-GREEN-REFACTOR TDD on controllers, asserts response codes / redirects / form errors / CSRF, exercises authenticated and anonymous clients, integrates with DAMA Doctrine test bundle for transaction rollback per test, and uses ParaTest for parallel execution. Distinct from `gerard:api-platform-tests` (which targets REST / JSON-LD via `ApiTestCase`). Trigger on "WebTestCase", "test a controller", "test a form submission", "redirect after POST", "test CSRF", "convert bug report into a failing test", or "functional test for server-rendered page".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Functional tests (Symfony — non-API)

## Use when
- Writing functional tests for server-rendered controllers (Twig pages, form submissions, admin areas).
- Converting a bug report into a failing test (RED-GREEN-REFACTOR).
- Exercising authentication flows (login form, redirects, access-denied).
- Asserting form validation errors, CSRF, redirects, flash messages.

> For REST / JSON-LD endpoints exposed by API Platform, use **`gerard:api-platform-tests`** instead — it covers `ApiTestCase`, schema assertions, JSON-LD pagination shape, JWT clients, etc.

## Default workflow
1. RED: write a failing functional test that captures the target behavior.
2. GREEN: implement the smallest controller / form change that makes the test green.
3. REFACTOR: clean up controller and template while the test stays green.
4. Broaden coverage to authorization (anonymous / forbidden / authorized) and error paths.

## Guardrails
- **Assert observable behavior, not internal state.** Status codes, redirects, rendered content, flash messages — not service internals.
- **Deterministic fixtures.** Foundry factories or `ResetDatabase` / DAMA transaction rollback per test.
- **No order coupling.** Each test starts from a clean state.
- **CSRF on by default.** If a form omits CSRF in the test, the test should fail.
- **Real templates render** — don't mock the renderer in functional tests; the goal is the full HTTP stack.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full patterns: WebTestCase skeleton, login helpers, form submission, redirect assertions, flash messages, CSRF, DAMA setup, scenario-based naming, ParaTest invocation.

## Output contract
- A `tests/Functional/<Area>/<Feature>Test.php` extending `WebTestCase`.
- Tests covering happy path + anonymous + forbidden + invalid form paths.
- DAMA / ResetDatabase guarantees test isolation.

## References
- `reference.md`
