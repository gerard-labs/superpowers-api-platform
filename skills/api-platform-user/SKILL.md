---
name: api-platform-user
description: Implement the canonical API Platform 4.3 + Symfony 7.4+ User entity — `User implements UserInterface, PasswordAuthenticatedUserInterface`, `#[UniqueEntity('email')]`, a transient `$plainPassword` validated only on `user:create`, the persisted hashed `$password` excluded from every serialization group, a `UserPasswordHasher` State Processor decorating `api_platform.doctrine.orm.state.persist_processor` to hash on POST/PUT/PATCH + nuke `plainPassword` from memory, a Repository implementing `PasswordUpgraderInterface` for automatic rehashing when the algorithm cost changes, and a `/me` endpoint backed by a `CurrentUserProvider` (Provider-based, REST + GraphQL compatible — not a custom controller). Includes the lightweight `md5` password hashing config for the test environment to speed the suite ×5. Trigger on "User entity", "password hashing", "/me endpoint", "registration", or "current user".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — User entity (UserInterface, password hashing, `/me`)

## Use when
- Bootstrapping a new project that needs authenticated users.
- Adding registration (`POST /api/users` open) + self-profile updates (`PUT /api/users/{id}` constrained to `object == user`).
- Exposing the current authenticated user via `/me`.
- Adopting auto-rehashing when the password hashing algorithm evolves.

## Default workflow
1. Implement `User implements UserInterface, PasswordAuthenticatedUserInterface`. Persist `$password` (hashed), keep `$plainPassword` transient.
2. Apply `#[UniqueEntity('email')]` + `Default` + `user:create` validation context on the POST operation.
3. Write the `UserPasswordHasher` State Processor that decorates `persist_processor` and hashes `$plainPassword`, then nukes it from memory.
4. Implement `PasswordUpgraderInterface` in the Repository for transparent rehashing.
5. Add the `/me` endpoint via a `CurrentUserProvider` (Provider-based, REST + GraphQL compatible).
6. Configure `md5` hashing only in `config/packages/test/security.yaml` to speed the test suite ×5.

## Guardrails
- **`$password` is NEVER in a serialization group.** It must not appear in any response.
- **`$plainPassword` is NEVER persisted** (no `#[ORM\Column]`), only validated on `user:create`.
- **Hashing in the Processor**, not in the controller — that's the canonical 4.x pattern.
- **`/me` via Provider, not Controller** — for REST + GraphQL compatibility.
- **Hash-light in tests** only — never in any other environment.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full entity, Processor, Repository with `PasswordUpgraderInterface`, `/me` Provider, test hashing config, and best practices.

## Output contract
- A `User` entity following the canonical pattern.
- A `UserPasswordHasher` Processor that hashes and nukes `$plainPassword`.
- A `UserRepository implements PasswordUpgraderInterface` for auto-rehashing.
- A `/me` endpoint backed by `CurrentUserProvider`.
- Test-only password hashing config in `config/packages/test/security.yaml`.

## References
- `reference.md`
