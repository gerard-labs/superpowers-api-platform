---
name: api-platform-mutators
description: Use API Platform 4.3's new `#[AsResourceMutator(resourceClass: …)]` and `#[AsOperationMutator(operationName: …)]` to mutate resource/operation metadata at **build time** — zero runtime cost. Implement `ResourceMutatorInterface::__invoke(ApiResource $resource): ApiResource` to e.g. prefix every operation's `routePrefix`, or `OperationMutatorInterface::__invoke(Operation $operation): Operation` to e.g. inject an extra serialization group. Includes the decision matrix between Mutator (build-time, cached, applies always) and Context Builder (runtime, per-request, role-/user-/header-dependent — see `api-platform-serialization`). Trigger on "apply the same change to every operation of a resource", "global API prefix injected from code", or "build-time metadata modification".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — Resource & Operation Mutators (NEW 4.3)

## Use when
- You want to apply a uniform metadata change to a resource (prefix routes, inject a group) without touching every operation by hand.
- The change is **decidable at build time** (no runtime dependency on the request).
- You're tempted to write a Context Builder for something that does not depend on the request — Mutator is cheaper.

## Default workflow
1. Decide: build-time (Mutator) or runtime (Context Builder)?
2. For a resource-wide change, implement `ResourceMutatorInterface` and annotate with `#[AsResourceMutator(resourceClass: Book::class)]`.
3. For a single-operation change, implement `OperationMutatorInterface` and annotate with `#[AsOperationMutator(operationName: '_api_Book_get_collection')]`.
4. Return the modified `ApiResource` / `Operation` (these objects are immutable — use `with*()` mutators).

## Guardrails
- **Mutator = build time**, no access to the request / user / locale. If you need any of those, use a Context Builder.
- **`Operation` and `ApiResource` are immutable.** Always use `withOperations()`, `withNormalizationContext()`, `withRoutePrefix()`, etc.
- **Operation names** are stable (`_api_<ShortName>_<operation>` by convention). Pin them in a constant if you reference them in multiple mutators.

## Progressive disclosure
- `SKILL.md` covers posture and decision tree.
- `reference.md` carries the full `AsResourceMutator` and `AsOperationMutator` recipes + the Context Builder vs Mutator comparison table.

## Output contract
- Mutators in `src/ApiPlatform/Mutator/` with explicit `#[AsResourceMutator]` / `#[AsOperationMutator]` annotations.
- Build-time metadata changes verified via `php bin/console debug:router | grep api` and `php bin/console api:openapi:export --yaml`.
- A short comment in each mutator explaining what it changes and why.

## References
- `reference.md`
