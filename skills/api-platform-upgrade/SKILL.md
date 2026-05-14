---
name: api-platform-upgrade
description: Migrate an API Platform codebase from 3.x or 4.0–4.2 up to 4.3. Trigger when composer.lock shows api-platform/* < 4.3, when grep finds #[ApiFilter] / openapiContext / hydra:* / ApiPlatform\\Core\\ / AbstractFilter / SerializerAwareProviderInterface / SerializableProvider / event_listeners_backward_compatibility_layer in src/, or when 4.x default flips need attention (hydra_prefix:false, standard_put:true, rfc_7807_compliant_errors:true, pagination_items_per_page:30, eager_loading.force_eager:true). Covers the lyrixx/rector-apip-openapi Rector script + the 4.3-specific breaks (mandatory `property` on Exact/Iri/Partial/Uuid filters; readonly entities no longer auto-expose PUT/PATCH). This is the dedicated migration playbook — every other skill in this plugin targets 4.3 exclusively.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform — Upgrade Guide (3.x → 4.x → v5 prep)

## Use when
- A `composer.lock` analysis (session hook) shows API Platform < 4.3.
- Reviewing or migrating code that still imports `ApiPlatform\Core\`, uses `#[ApiFilter]`, `openapiContext`, or implements `SerializerAwareProviderInterface` / `SerializableProvider`.
- Bulk-renaming filters from the legacy classes to the modern 4.3 equivalents.
- Planning the v5 cut-over (preventing regressions via PHPStan / Deptrac).

## Default workflow
1. Determine the starting version from `composer.lock`. Hard-stop on 3.x without explicit planning.
2. Apply the 3.x → 4.0 macro-changes (namespaces, package split, Providers/Processors, defaults).
3. Apply the 4.0 → 4.2 changes (modern filter pattern using `parameters: [QueryParameter]`).
4. Apply the 4.2 → 4.3 breaks (explicit `property` on Exact/Iri/Partial/Uuid filters; review readonly entities; check `@type` consumers).
5. Run the Rector script for `openapiContext` and inspect for any remaining legacy references.
6. Enable v5-prep guards (PHPStan rule, Deptrac layer) to prevent regressions.

## Guardrails
- **Do not migrate without a passing test suite.** Re-baseline tests if they assert `hydra:member` (replace by `member`).
- **Default flips in 4.x** can break consumers: `hydra_prefix:false`, `standard_put:true`, `rfc_7807_compliant_errors:true`, `pagination_items_per_page:30`. Audit clients before flipping.
- **`eager_loading.force_eager: true`** is the 4.x default but often counter-productive — set it to `false` and use targeted join fetches.
- **Only this skill** is allowed to mention `#[ApiFilter]`, `openapiContext`, `hydra:member`, `extends AbstractFilter`, etc. The lint script rejects them elsewhere.

## Progressive disclosure
- `SKILL.md` summarizes the migration path.
- `reference.md` carries the full tables: 3.x → 4.0 macro changes, 4.0 → 4.2 filter shift, 4.2 → 4.3 breaks, behavioral changes (isGranted pre-provider, Hydra `#ShortName`, LDP headers), 4.3 novelties, removed-in-v5 list, full legacy → modern mapping, tooling (Rector, PHPStan rule, Deptrac), `composer outdated` audit.

## Output contract
- A migration plan in three steps (3.x → 4.0 → 4.2 → 4.3).
- All `#[ApiFilter]` annotations replaced by `parameters: [QueryParameter]`.
- All `openapiContext: […]` replaced by `openapi: new Model\Operation(…)`.
- All `hydra:member` / `hydra:totalItems` references replaced in tests.
- No `ApiPlatform\Core\` imports remaining.
- `SerializerAwareProviderInterface` / `SerializableProvider` implementations deleted.

## References
- `reference.md`
- Upstream upgrade guide: <https://api-platform.com/docs/core/upgrade-guide/>
- Rector script: <https://github.com/lyrixx/rector-apip-openapi>
