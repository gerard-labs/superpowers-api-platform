---

name: tdd-with-pest
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Apply RED-GREEN-REFACTOR TDD with Pest PHP on a Symfony project — `test()` / `it()` blocks, expectation pipeline (`expect($x)->toBe()->toBeInstanceOf()`), `beforeEach()` / `afterEach()`, datasets via `with(...)`, higher-order tests, Pest plugins (Faker, Stress, Snapshot), parallel runner. Use Foundry factories for fixtures, DAMA Doctrine Test Bundle for transaction-rollback. Trigger on "write a Pest test", "TDD this feature", or "convert PHPUnit to Pest". For PHPUnit-syntax preference, see `gerard:tdd-with-phpunit`.
---

# Tdd With Pest (Symfony)

## Use when
- Building regression-safe behavior with TDD/functional/e2e tests.
- Converting bug reports into executable failing tests.

## Default workflow
1. Write failing test for target behavior and one boundary case.
2. Implement minimal code to pass.
2. Refactor while preserving green suite.
2. Broaden coverage for invalid/unauthorized/not-found paths.

## Guardrails
- Prefer deterministic fixtures/builders.
- Assert observable behavior, not internal implementation.
- Keep tests isolated and stable in CI.

## Progressive disclosure
- Use this file for execution posture and risk controls.
- Open references when deep implementation details are needed.

## Output contract
- RED/GREEN/REFACTOR trace.
- Test files changed and executed commands.
- Coverage and confidence notes.

## References
- `reference.md`
- `docs/complexity-tiers.md`
