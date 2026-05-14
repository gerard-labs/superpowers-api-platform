---
name: symfony-voters
description: Implement Symfony Voters for fine-grained, object-level authorization — `Voter::supports($attribute, $subject)` filtering by attribute prefix (`POST_VIEW`, `POST_EDIT`, `POST_DELETE`, `POST_CREATE`) and subject class, `Voter::voteOnAttribute($attribute, $subject, $token)` returning the decision based on user roles and object state (ownership, publication status). Wire via `is_granted('POST_VIEW', $post)` from controllers, `#[IsGranted('POST_EDIT', subject: 'post')]` attributes, API Platform operation `security:` expressions, or programmatically through `Symfony\\Bundle\\SecurityBundle\\Security::isGranted()`. Test each voter in isolation with PHPUnit, asserting permit / deny / abstain branches. Trigger on "voter", "authorization", "object-level permissions", "ownership check", or "is_granted not granular enough".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Symfony Voters

## Use when
- A `security:` expression on an API Platform operation becomes longer than one boolean clause.
- The authorization depends on the object state (owner, published, status).
- Different actions on the same resource need different permission rules.
- You want to test the authorization logic in isolation from controllers / providers.

## Default workflow
1. Define the attribute vocabulary (`POST_VIEW`, `POST_EDIT`, `POST_DELETE`, `POST_CREATE`).
2. Implement a `Voter` with `supports()` returning `true` only for the relevant attribute + subject combination.
3. Implement `voteOnAttribute()` returning `true` only when the action is allowed.
4. Wire `is_granted('POST_VIEW', $post)` in controllers, API operations, or Twig templates.
5. Test each voter in isolation with PHPUnit — permit / deny / abstain.

## Guardrails
- **Fail closed.** If `supports()` returns `false`, the voter abstains. If it supports the attribute but the action is not granted, return `false`.
- **One Voter per resource type.** Keep the file small and the matrix readable.
- **Inject `Security`**, never the request — voters must work outside the HTTP cycle.
- **Test every permission matrix entry.** Permit, deny, abstain (when applicable).
- **No business logic in voters** — they read state and decide. Mutations belong elsewhere.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full Voter implementation pattern, integration recipes (API Platform, controller `#[IsGranted]`, Twig), naming conventions, and isolated-testing pattern.

## Output contract
- A `src/Security/Voter/<Resource>Voter.php` file per resource type.
- `is_granted('<RESOURCE>_<ACTION>', $subject)` used at the integration points.
- A `tests/Security/Voter/<Resource>VoterTest.php` covering every attribute × scenario combination.

## References
- `reference.md`
