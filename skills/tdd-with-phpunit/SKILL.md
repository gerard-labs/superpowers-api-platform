---
name: tdd-with-phpunit
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
description: Apply RED-GREEN-REFACTOR TDD with PHPUnit 12 on a Symfony project — `extends TestCase` / `KernelTestCase` / `WebTestCase`, attributes (`#[DataProvider]`, `#[Group]`, `#[CoversClass]`, `#[Depends]`), PHPUnit 12 accepts both `test_business_behavior` snake_case AND `testBusinessBehavior` camelCase (criterion: method starts with `test`), BDD-descriptive naming over implementation names. ParaTest for parallel runs. Trigger on "write a PHPUnit test", "TDD a Symfony service", or "RED-GREEN-REFACTOR a controller". For Pest-syntax preference, see `gerard:tdd-with-pest`.
---

# Tdd With Phpunit (Symfony)

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
