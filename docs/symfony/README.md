# API Platform & Symfony Documentation

This directory contains in-depth reference material for **API Platform 4.3+** running on **Symfony 7.4 LTS+**.

## Contents

### API Platform

- [API Platform 4.3 overview](api-platform-4.3-overview.md) — resources, operations, modern patterns
- [API Platform 4.3 configuration reference](api-platform-config-4.3.md) — full `api_platform.yaml` options and 4.x default flips
- [API Platform 4.3 anti-patterns](api-platform-anti-patterns.md) — checklist + PR review template

### Symfony

- (Most Symfony content lives in the dedicated skills under `../../skills/`. This directory keeps narrative-style references that are too long for a single skill.)

## Supported versions

| Component | Version |
|-----------|---------|
| API Platform | **4.3+** (required) |
| Symfony | **7.4 LTS** (Nov 2025) or **8.0+** (required) |
| PHP | **8.2+** (required) |

Older versions are out of scope for this plugin. The session-start hook warns explicitly if it detects an older version and points to the `gerard:api-platform-upgrade` skill.

## Quick links

- [API Platform 4.3 documentation](https://api-platform.com/docs/core/)
- [API Platform 4.3 upgrade guide](https://api-platform.com/docs/core/upgrade-guide/)
- [Symfony documentation](https://symfony.com/doc/current/index.html)
- [Doctrine ORM documentation](https://www.doctrine-project.org/projects/orm.html)
- Full index of the 53 `gerard:*` skills shipped by this plugin: [`../../skills-map.md`](../../skills-map.md) (and [`skills-map-lite.md`](../../skills-map-lite.md) for the one-liner version).
