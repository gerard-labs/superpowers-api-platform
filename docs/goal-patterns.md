# Goal patterns

> The `/goal` condition templates used by `/api`. Source of truth lives in `skills/meta/goal-patterns/SKILL.md` ; this doc explains the rationale and gives concrete story examples per shape.

## Why a templating layer

The Claude Code `/goal` primitive (2.1.139+) takes a **verifiable natural-language condition** + a hard turn cap. A Haiku evaluator reads the condition each turn and decides whether to clear the goal.

If the condition were free-form prose, drift would creep in over runs : one team would write *"ideally APPROVE"*, another *"tests must pass"*, another *"acceptance criteria met"*. Haiku is lenient about hedging — the gate gets lower.

So we templatize. Every `/api` run composes its `/goal` condition from a **fixed base** (4 bullets) + **one shape addendum** (1 bullet). Nine shapes are recognized. The output is a precise, unambiguous condition string that the evaluator can match consistently.

## The base condition (always present)

```text
Goal cleared when:
  1. gerard-gatekeeper returned VERDICT=APPROVE on its last review
  2. AppSec bilan in the latest gatekeeper report has no H1/H2 findings open
  3. all listed test commands pass (status 0 from the session-start runner)
  4. no anti-patterns flagged by post-tool-use hook in the last 3 tool calls
```

**These four bullets are non-negotiable.** Every shape inherits them. They encode the v1.0 enforcement promise :

| Bullet | What it enforces | Why |
|---|---|---|
| 1. gatekeeper APPROVE | The 39-rule adversarial review passed | Last line of defense before merge |
| 2. AppSec H1/H2 zero | No high-severity AppSec finding open | Blocking-grade security gate |
| 3. tests green | All listed test commands return 0 | Runtime correctness gate |
| 4. hook-clean | No regex / phpstan block in the last 3 tool calls | Inline anti-pattern enforcement |

Bullet 4 has a 3-tool-call window because the implementer may legitimately hit a phpstan block, fix it, and continue — we don't want a transient block early in the loop to permanently disqualify the goal.

---

## The 9 shapes

`/api` step 3 (story classification) picks exactly one shape based on keyword heuristics. The matching addendum gets appended as bullet 5.

### `new-resource`

> Trigger keywords : "add resource", "new entity", "new resource", "create X resource"

Addendum :

```text
  5. The new resource is reachable via `GET /api/<plural>` and has at least one functional test.
```

#### Example stories that map here

- *"Add a Product resource with name, price and BackedEnum status (DRAFT|PUBLISHED|ARCHIVED)."*
- *"Create a Tender resource exposing GetCollection + Post + Get, with the typical fields."*
- *"New resource : Invoice (read-only, IRI from existing Order)."*

#### Why this addendum

The shape promises a **reachable** resource. The functional test is the receipt — without one, the implementer might have configured the resource without verifying the routing kicks in. The `<plural>` substitution is computed by `/api` step 4 from the STORY (Product → products, Invoice → invoices).

---

### `new-operation`

> Trigger keywords : "add Patch", "expose Delete", "new operation on"

Addendum :

```text
  5. The new operation has a functional test and is documented in OpenAPI.
```

#### Example stories

- *"Add a Patch operation on the Product resource to update status only."*
- *"Expose Delete on Order (with Voter restricting to admin)."*
- *"Add a custom POST `/api/orders/{id}/refund` operation."*

#### Why this addendum

New operations are easy to misconfigure (wrong HTTP method, missing OpenAPI summary, no test coverage). The dual proof — functional test + OpenAPI documentation — locks both behavioral and discoverability completeness.

---

### `new-filter`

> Trigger keywords : "filter", "search by", "sort by", "facet"

Addendum :

```text
  5. The filter is declared in the resource operations array (parameters: [QueryParameter])
     and has a functional test covering at least one positive + one negative case.
```

#### Example stories

- *"Filter the Product collection by status."*
- *"Add a free-text search on Product.name."*
- *"Sort Product by createdAt descending by default ; expose a `sort` parameter."*

#### Why this addendum

The most common anti-pattern (rule 1 in [`anti-patterns.md`](anti-patterns.md)) is `#[ApiFilter(SearchFilter::class)]` on the entity instead of `parameters: [QueryParameter]` on the operation. The addendum makes the canonical pattern explicit. The positive + negative test pair catches off-by-one (filter "matches everything" or "matches nothing").

---

### `new-state-flow`

> Trigger keywords : "state processor", "state provider", "workflow"

Addendum :

```text
  5. State Processor/Provider is wired via `processor:` / `provider:` on the operation
     and unit-tested.
```

#### Example stories

- *"Add a State Processor on Post Order that triggers an async Messenger handler for fulfillment."*
- *"Replace the default Doctrine collection provider on Product with a header-versioned one."*
- *"Add a CQRS bus bridge State Processor for the Refund operation."*

#### Why this addendum

State Processors and Providers are easy to declare but not wire (the operation array needs `processor: MyProcessor::class` or `provider: MyProvider::class`). The unit test gives evidence the class is invoked, not just registered.

---

### `migration`

> Trigger keywords : "migrate", "doctrine migration", "schema change"

Addendum :

```text
  5. Doctrine migration applies cleanly + has a down() that reverses it.
```

#### Example stories

- *"Migrate the Product.status column from VARCHAR to a BackedEnum-compatible value."*
- *"Add an index on Order.created_at for the new pagination cursor."*
- *"Drop the legacy `order_items_archive` table (data already moved)."*

#### Why this addendum

Doctrine migrations are the riskiest piece of any feature — they run in production with no rollback by default. The `down()` reversibility is **the** zero-downtime requirement. The addendum forces the implementer to test both directions.

---

### `bugfix`

> Trigger keywords : "fix", "bug", "regression", "crash"

Addendum :

```text
  5. A regression test reproduces the bug pre-fix and passes post-fix.
```

#### Example stories

- *"Fix the 500 returned by /api/orders when paginationPartial=true is used."*
- *"Fix the IRI converter throwing on empty payload."*
- *"Fix the JWT clock-skew issue (tokens rejected after a few seconds)."*

#### Why this addendum

The TDD-school addition. A bugfix without a regression test is one rebase away from re-introduction. The addendum's "reproduces pre-fix and passes post-fix" wording is double-edged — the test must have been **observed failing** at some point.

---

### `refactor`

> Trigger keywords : "refactor", "extract", "rename", "split"

Addendum :

```text
  5. Public API surface unchanged; existing tests still pass; no new responsibilities introduced.
```

#### Example stories

- *"Refactor the Order State Processor to extract the email-sending into a dedicated service."*
- *"Rename FooBar to OrderItem (keep the alias for one minor version)."*
- *"Split the monolithic ProductRepository into ProductReader + ProductWriter."*

#### Why this addendum

The anti-feature : a refactor that "while we're at it" sneaks in a behavior change is a refactor PR that should be split. The three clauses pin all three vectors of drift : surface, behavior, scope.

---

### `security-hardening`

> Trigger keywords : "harden", "auth", "JWT", "Voter", "CORS"

Addendum :

```text
  5. AppSec bilan contains an explicit row for the hardening with status=resolved + reproduction.
```

#### Example stories

- *"Harden the JWT validation : reject tokens older than 24h server-side (jti blacklist)."*
- *"Add a Voter on Order to enforce row-level ownership."*
- *"Lock CORS to the production domain list — currently allow_origin=['*']."*

#### Why this addendum

Hardening stories are validated by **threat model evidence**, not just code presence. The AppSec bilan row makes the threat explicit (what attack does this close?), and the reproduction proves it (was the attack actually demonstrable before, and not after?).

---

### `generic`

> Fallback when no other trigger matched.

No addendum — the base 4 bullets are the whole condition.

#### Example stories that fall here

- *"Document the public OpenAPI spec via Scalar UI."*
- *"Tweak the Renovate config to auto-merge patch updates."*
- *"Update the README."*

These are valid stories but don't fit any specialized shape. The base 4 bullets still apply — gatekeeper APPROVE + AppSec clean + tests pass + hook-clean.

---

## Composition rules

1. **Substitute `<plural>` and `<branch>` in the addendum** before passing to `/goal`. The `/api` step 4 has both values in scope (plural derived from the STORY, branch from `git symbolic-ref --short HEAD`).
2. **Cap at 12 turns** is set on the `/goal` invocation itself (decision verrouillée — [`v1.0-plan.md`](v1.0-plan.md) section 1, decision #7).
3. **Avoid hedge language**. The Haiku evaluator reads the rendered condition verbatim — words like *"ideally"*, *"if possible"*, *"should normally"* lower the gate. Be unambiguous.

## Adding a new shape

A team that wants a shape we didn't anticipate (e.g. *"performance optimization"*, *"data migration ETL"*) can :

1. Edit `skills/meta/goal-patterns/SKILL.md` and add a new addendum block under `## Shape addenda`.
2. Edit `commands/api.md` step 3 and add the trigger keywords for the new shape.
3. Re-run `rtk proxy npx tsx scripts/validate_skills.ts` to confirm the validator stays green.

This is one of the few user-edit-friendly extension points in v1.0.

---

## How `/api` reads the templates

```text
# commands/api.md step 4 (excerpted):

Read Skill gerard:meta/goal-patterns. Pick the addendum matching the detected shape.
Append it to the base condition. Substitute <plural> (from STORY) and <branch>
(from current symbolic-ref). Pass the result to /goal as the verifiable condition.
```

The skill returns the full base + all 9 shape addenda in its `high` variant. `/api` then selects the one addendum it needs. This indirection keeps the command lean (no hardcoded templates) and lets the templates evolve without touching the command.

---

## References

- `skills/meta/goal-patterns/SKILL.md` — the source of truth (templates + composition rules)
- `commands/api.md` step 4 — the caller that picks the addendum
- `agents/gerard-gatekeeper/agent.md` — produces the `VERDICT=APPROVE` that satisfies bullet 1
- `hooks/post-tool-use.sh` — produces the hook-clean signal for bullet 4
- [`v1.0-plan.md`](v1.0-plan.md) section 1 decision #7 — Cap at 12 turns rationale
- [`commands.md`](commands.md) — `/api` reference
