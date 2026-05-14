# Anti-patterns

> **Source of truth** for the 24 base anti-patterns + the gatekeeper's extended rules (tests, AppSec, project conventions). When in doubt, this doc wins.

## Why this doc exists

In v0.1, anti-pattern lists were duplicated across several artefacts (reviewer agent, implementer agent, self-audit command, runtime regex hook). They drifted apart over time. In v1.0, the canonical list lives in **one place** : `skills/meta/anti-patterns-audit/SKILL.md`. This doc is its user-facing narrative, plus the extensions (tests, AppSec, Make project conventions) that the gatekeeper applies on top.

## Where each rule is enforced

| Layer | Enforcement | Covers |
|---|---|---|
| **PostToolUse hook** (`hooks/post-tool-use.sh`) | Deterministic, inline, blocks the Write/Edit | The 7 highest-signal regex patterns (subset of rules 1-24) |
| **Implementer self-audit** (step 5 of `api-implementer/agent.md`) | Y/N checklist filled in the DoD report | Full 24 base rules |
| **`gerard:meta/anti-patterns-audit` skill** (invocable hors-pipeline) | Y/N checklist with file:line evidence | Full 24 base rules + `xhigh` project overrides |
| **gerard-gatekeeper** (review stage) | Auto-`VERDICT: REQUEST_CHANGES` on any hit | All 39 rules (24 base + 15 extensions) |

A single violation in the gatekeeper's pass = `VERDICT: REQUEST_CHANGES`. No "follow-up" path for these.

---

## The 24 base rules

### API Platform 4.3 (rules 1-16)

#### Filters & queries (4)

1. **`#[ApiFilter(...)]` in new code** — 4.2-deprecated. Use `parameters: [new QueryParameter(filter: new ExactFilter(), property: 'sku')]`. **Allowed only** inside `skills/api-platform-upgrade/` examples.
2. **`extends AbstractFilter`** in new code. Use `implements FilterInterface` + `BackwardCompatibleFilterDescriptionTrait` + `JsonSchemaFilterInterface` + `OpenApiParameterFilterInterface`.
3. **Filter without explicit `property:`** in 4.3 on Exact / Iri / Partial / Uuid filters — `InvalidArgumentException` at compile time since 4.3.
4. **Legacy filter classes referenced** : `SearchFilter`, `OrderFilter`, `DateFilter`, `RangeFilter`, `NumericFilter`, `BooleanFilter` — banned in new code.

#### Operations & serialization (6)

5. **`openapiContext: [...]`** keyword. Use `openapi: new \ApiPlatform\OpenApi\Model\Operation(...)`. Rector available: `lyrixx/rector-apip-openapi`.
6. **`hydra:member`, `hydra:totalItems`, `hydra:view`, `hydra:next`** in test assertions. 4.x default is `hydra_prefix: false` ; tests should use `member`, `totalItems`, etc.
7. **Scalar ID in DTO payload** (e.g. `int $customerId`) instead of IRI (`Customer $customer`). IRI-only on relations is non-negotiable.
8. **Free `string` for status** instead of `BackedEnum`. Any status / type / category column.
9. **Missing `MaxDepth`** on circular relations in the normalization context.
10. **Auto-increment `int` ID on a public resource** without justification. Use UUID v7 / ULID for anti-enumeration.

#### Namespaces & deprecated interfaces (3)

11. **`ApiPlatform\Core\…` imports** — namespace was renamed in 4.x. Use `ApiPlatform\...`.
12. **`SerializerAwareProviderInterface`** or **`SerializableProvider`** implemented — deprecated 4.2, removed v5.
13. **`event_listeners_backward_compatibility_layer: true`** or **`keep_legacy_inflector: true`** in config — 3.x legacy flags.

#### Performance & security (3)

14. **`eager_loading.force_eager: true`** on entity with many relations without justification. Use `false` + targeted join fetches.
15. **MCP exposed** (`#[McpTool]`) **without dedicated rate limit + audit log** on `/mcp`.
16. **CORS `allow_origin: ['*']` with `allow_credentials: true`** — CSRF / exfiltration vector.

### Symfony 7.4+ (rules 17-24)

17. **`// TODO`, `// FIXME`, `// XXX`** or wholesale-commented code blocks in the diff.
18. **`@phpstan-ignore`** or **`@psalm-suppress`** without a `// reason:` line citing a specific framework/vendor constraint.
19. **`mixed` in a public signature** (method param or return type).
20. **Symfony 6.4 / 7.0 / 7.1 / 7.2 / 7.3** referenced as supported. Plugin targets 7.4 LTS+ only.
21. **`@phpstan-ignore-next-line`** cumulé at file level (no granular justification).
22. **Hidden `@throws`** without exception in signature for checked exception cases.
23. **Reverse proxy in dev without `SYMFONY_TRUSTED_PROXIES`** — URLs HTTP instead of HTTPS, WDT broken, mixed content.
24. **Twig `<script>` emitter** without `csp_nonce('script')` when CSP `strict-dynamic` is in use.

> Note : the implementer agent's auto-reject list embeds an expanded set (19 API Platform entries + 4 Symfony entries) that includes a few duplicates and a few hook-redundant ones for safety-net coverage. The 24 above are the **canonical** set the gatekeeper runs.

---

## The 7-regex fast-feedback subset

These are the rules the `PostToolUse` hook scans inline on every `*.php` write. They mirror the highest-signal patterns and have near-zero false-positive rate.

| # | Pattern | Maps to base rule |
|---|---|---|
| 1 | `\b(dd\|dump\|var_dump\|var_export\|print_r)\s*\(` | (debug residue — outside the base 24 but caught here) |
| 2 | `//\s*(TODO\|FIXME\|XXX)` | Rule 17 |
| 3 | `:\s*mixed\b` (return type) | Rule 19 |
| 4 | `@ApiPlatform\\` (legacy 3.x annotation) | Rule 11 (kindred) |
| 5 | `operations:\s*\[\s*new Get\(\)\s*,\s*new GetCollection\(\)\s*\]` | (manual default ops — outside the base 24 but caught) |
| 6 | `(localhost\|127\.0\.0\.1)` in non-test code | (hard-coded URL — outside the base 24 but caught) |
| 7 | (reserved — extend in your fork) | — |

Source : `skills/meta/anti-patterns-audit/SKILL.md` step 2. The hook script is `hooks/post-tool-use.sh`.

---

## Gatekeeper-only extensions (rules 25-39)

These extend the 24 base rules at the gatekeeper layer. They are not scanned by the regex hook.

### Project conventions (rule 25)

25. **Custom Make target added to the framework `Makefile`** when `Makefile-solution` exists in the project. The boilerplate regenerates `Makefile` ; custom targets must go in `Makefile-solution`. The session hook surfaces `makefile.solution_file` — if it's non-null and the diff touches the primary Makefile, REQUEST_CHANGES. See `gerard:makefile-discipline`.

### Test rules (rules 26-32)

26. **Public method without a corresponding test**.
27. **API Platform endpoint without `ApiTestCase`** covering happy + 401 + 403 + 422 + 404 (+ 409 if uniqueness).
28. **Tautological test** detected — passes with AND without the production code, or asserts the call against itself.
29. **AC from the plan's test matrix without a corresponding test**. Orphan AC = reject.
30. **Test naming implementation-style** (`testCalculateReturnsValue`, `testFooBar1`). Accept BDD descriptive (snake_case or camelCase).
31. **MSI < 80% on critical path** (handlers domain, value objects with invariants, aggregates, processors mutating state, voters, finance/rights/PII code).
32. **Test default page size = 20** (was 3.x). 4.x default is 30.

### AppSec rules (rules 33-39)

33. **Controller calling `$repo->find($id)`** and operating on the entity without a Voter check first.
34. **DTO with `Assert\NotBlank`** but no `Assert\Length(max=...)` — memory blow-up vector.
35. **New endpoint without explicit `security:`** or `IsGranted`.
36. **Secrets / credentials hardcoded** in source control.
37. **File upload without MIME + magic byte validation**.
38. **JWT stored in `localStorage`** instead of HttpOnly cookie. (Also caught at base rule 16 territory in some forms ; the AppSec entry is the canonical phrasing.)
39. **AppSec finding from the plan's `## Security — AppSec findings` not mitigated** in the diff (with `bloque le merge` verdict from the appsec worker).

For rule 39, the gatekeeper reproduces the AppSec findings table in its verdict, with each finding's status :

```
| # | Risque | Statut |
|---|--------|--------|
| H1 | SSRF via URL preview | resolved (allow-list at src/Http/Client/...) |
| H2 | IRI leak | resolved (UUID v7 + IRI-only at src/ApiResource/...) |
| M1 | Mass assignment | accepted — groups explicit at src/Dto/... |
```

Without this AppSec bilan, an `APPROVE` is non-auditable — the section is **mandatory**.

---

## How to fix each rule

### Filter rules (1-4)

```php
// ❌ Rule 1
#[ApiResource(operations: [...])]
#[ApiFilter(SearchFilter::class, properties: ['sku' => 'exact'])]
class Product { ... }

// ✅ Rule 1 — modern parameters pattern (4.3)
new GetCollection(
    parameters: [
        'sku' => new QueryParameter(filter: new ExactFilter(), property: 'sku'),
    ],
)
```

```php
// ❌ Rule 2
final class TenantFilter extends AbstractFilter { ... }

// ✅ Rule 2 — modern interface
final class TenantFilter implements FilterInterface, JsonSchemaFilterInterface, OpenApiParameterFilterInterface
{
    use BackwardCompatibleFilterDescriptionTrait;
    // ...
}
```

### OpenAPI rule 5

```php
// ❌ Rule 5
new Get(openapiContext: ['deprecated' => true, 'summary' => 'Legacy endpoint'])

// ✅ Rule 5
new Get(openapi: new Operation(deprecated: true, summary: 'Legacy endpoint'))
```

### IRI rules 7, 10

```php
// ❌ Rules 7 + 10
final class OrderInput
{
    public int $customerId;       // scalar — enumerable, leaks the ID
}

// ✅ Rules 7 + 10
final class OrderInput
{
    public Customer $customer;    // IRI — opaque, served by IriConverter

    #[ApiProperty(identifier: true)]
    public Uuid $id;              // UUID v7
}
```

### Status as BackedEnum (rule 8)

```php
// ❌ Rule 8
public string $status = 'draft';

// ✅ Rule 8
public OrderStatus $status = OrderStatus::Draft;

enum OrderStatus: string
{
    case Draft = 'draft';
    case Published = 'published';
    case Archived = 'archived';
}
```

### Symfony 7.4+ hygiene (rules 17-22)

```php
// ❌ Rule 17
// TODO: handle the edge case where customer is null

// ❌ Rule 19
public function process(mixed $input): mixed { ... }

// ✅ Rules 17, 19
public function process(OrderInput $input): OrderOutput
{
    if ($input->customer === null) {
        throw new BusinessLogicException('Customer is mandatory');
    }
    // ...
}
```

For more code-level examples, see the corresponding `gerard:*` skill (each one carries its own canonical patterns).

---

## How the implementer self-audits

The implementer's DoD report includes a Y/N checklist (step 5 of `api-implementer/agent.md`) :

```text
Anti-patterns API Platform 4.3 — diff check:
- [Y/N] No #[ApiFilter] used (parameters: [QueryParameter] modern pattern)
- [Y/N] No extends AbstractFilter
- [Y/N] No openapiContext
- [Y/N] No 'hydra:*' in tests
- [Y/N] No ApiPlatform\Core\ imports
- [Y/N] IRI-only on relations (no scalar IDs)
- [Y/N] BackedEnum for statuses
- [Y/N] Filter has explicit property: (4.3 requirement)
- [Y/N] MaxDepth on circular relations
- [Y/N] UUID v7 / ULID for public identifiers
- [Y/N] No EntityManager injected in Provider
- [Y/N] Default page size 30 in tests
- [Y/N] No SerializerAwareProviderInterface / SerializableProvider
- [Y/N] No event_listeners_backward_compatibility_layer / keep_legacy_inflector
- [Y/N] MCP tools (if any) have rate limit + audit log
```

If any answer is "N" without justification, the gatekeeper rejects.

---

## How to invoke the standalone audit

Hors-pipeline (e.g. before opening a PR by hand) :

```text
Skill gerard:meta/anti-patterns-audit
```

The skill takes a target :

- `target: diff` (default) — audit `git diff --cached`
- `target: branch` — audit `git diff main...HEAD`
- `target: <glob>` — audit files matching the glob

Output is a markdown report with the 7-regex fast pass + 24-rule structured checklist + summary (severity breakdown, recommendation).

---

## Adding project-specific rules

To extend the audit with project-specific patterns, ship a `.claude/skills/<project>/anti-patterns-audit/SKILL.md` that follows the same shape. The audit skill (in `xhigh` mode) cross-checks `.claude/skills/*/anti-patterns-audit/SKILL.md` and applies the extra rules.

Example use case : a project enforces "no `Assert\Email` without `mode: strict` since RFC 5321 deviation caused incidents". Ship the rule in `.claude/skills/myapp/anti-patterns-audit/SKILL.md` so the gatekeeper checks it on every diff.

---

## References

- `skills/meta/anti-patterns-audit/SKILL.md` — the canonical skill (source of truth)
- `hooks/post-tool-use.sh` — the 7-regex inline subset
- `agents/api-implementer/agent.md` step 5 — self-audit checklist
- `agents/gerard-gatekeeper/agent.md` — the 39-rule review checklist
- [`agents.md`](agents.md) — agents that enforce these rules
- [`hooks.md`](hooks.md) — the PostToolUse hook
