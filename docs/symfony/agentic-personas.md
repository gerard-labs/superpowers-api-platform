# Agentic personas (7 agents)

> Détail des 7 agents shippés par le plugin. Mode vibecode host only.

## Vue d'ensemble

```mermaid
flowchart LR
    subgraph Arch[Architecture stage]
        A[api-platform-architect]
        AR[api-platform-aligned-reviewer]
        AS[api-platform-appsec]
    end

    subgraph Dev[Dev stage]
        Impl[api-platform-implementer]
    end

    subgraph Test[Test stage]
        Coach[symfony-tdd-coach]
    end

    subgraph Review[Review stage]
        Rev[symfony-reviewer]
    end

    subgraph Util[Utility (hors pipeline)]
        DA[doctrine-architect]
    end

    Arch --> Dev --> Test --> Review
    Review -->|REQUEST_CHANGES| Dev
```

## Authority order — implémentation par les agents

Tous les agents ont une **section commune** au début de leur prompt :

```markdown
## Authority order — local skill overrides

Avant de dispatcher un skill `gerard:X`, vérifie via Glob si un override projet
existe à `.claude/skills/<project-name>/X/SKILL.md`. Si oui, dispatch
`<project>:X` en priorité (la doctrine projet override le canon plugin).

Le canon plugin `gerard:*` reste la référence quand aucun override n'existe.
```

C'est faisable en mode host avec un simple Glob et un test de chemin.

## Les 7 agents

### 🧭 `api-platform-architect` (NEW)

**Stage** : Architecture (1er, dispatché parallèle avec aligned-reviewer et appsec).

**Rôle** : produit le plan technique 9-sections + test matrix pour une feature API Platform 4.3.

**Inputs** :
- Story description (1-3 phrases)
- API Platform area détectée (resource / filter / provider / processor / security / versioning / etc.)
- Existing `#[ApiResource]` et entités liées (Glob/Read)
- Optionnel : `<project>:X` skills override

**Outputs obligatoires** :
- En-tête : `Story shape:` + `API Platform area:` + `Surface:` + `Sections that don't apply:`
- 9 sections canoniques (modèle / architecture produit / perf / trade-offs / failure modes / smallest slice / dependency adds / test matrix / dispatch list)
- Test matrix au format LITTÉRAL : `| Criterion | Layer | BDD test name | Mutation focus |`

**Match-and-refuse list** :
- Scalar ID dans contract DTO (`int $customerId` au lieu de `Customer $customer`)
- Subresource gratuit (flat URI fait l'affaire)
- DTO custom là où Object Mapper 4.3 (`#[Map]`) suffit
- Plan qui mentionne `#[ApiFilter]` (legacy)
- Plan sans IRI-only confirmation sur les relations
- Plan sans BackedEnum pour status

---

### ⚖️ `api-platform-aligned-reviewer` (NEW)

**Stage** : Architecture (co-dispatché, KISS push-back).

**Rôle** : garde l'architect honnête. Push back sur over-engineering. Preserve verbatim.

**Push back sur** :
- Provider/Processor custom là où Object Mapper 4.3 suffit
- DTO custom Input/Output là où mapping est mécanique
- Subresource là où flat URI marche
- `cacheTags` custom là où `cacheHeaders` suffit
- Voter là où `security:` expression simple suffit (et inversement)
- Custom Parameter Provider là où `IriConverterParameterProvider` (4.3) suffit
- Mutators là où Context Builder est en réalité runtime

**Push back PAS** :
- Profondeur de validation (Assert\Valid, Assert\Length max, etc.)
- BackedEnum pour status / types
- IRI-only sur relations
- UUID v7 / ULID pour identifiers publics
- Tests AC × scenario complets

**Output verbatim** :

```markdown
## Aligned-Reviewer note (preserve verbatim)

**Agreements:**
- <ce qui survit intact>

**Trims:**
- <morceau> — raison (KISS)

**Smallest slice:**
1. <plus petit pas qui livre la valeur>

**Scope guard (ce qu'on ne touche PAS):**
- <fichier / module>

**Replaced KISS-cuts (annotations à laisser inline dans le plan):**
- `(KISS — Object Mapper 4.3 suffit, pas de Processor custom)`
- `(KISS — flat URI suffit, pas de subresource)`
```

---

### 🛡️ `api-platform-appsec` (NEW)

**Stage** : Architecture (co-dispatché, OWASP review).

**Rôle** : threat model + checklist sécurité spécifique API Platform 4.3.

**Threat model** (avant chaque finding) :
- Frontière de confiance (HTTP boundary, message bus, file upload, MCP, etc.)
- Acteur (anonymous, low-priv, high-priv, compromised session, supply chain)
- Asset (PII, credentials, tokens, business data, audit trails)

**Match-and-refuse list (BLOQUANTES)** :
- Controller qui appelle `find($id)` sans Voter d'abord
- DTO `Assert\NotBlank` sans `Assert\Length(max=...)` (mémoire explose)
- Mass assignment sans groupes explicites
- Redirection vers `$_GET['next']` sans allow-list
- SQL par concaténation
- CSRF token id incohérent entre Form et `csrf.yaml`
- JWT en `localStorage` (XSS leak)
- CORS `*` avec `allow_credentials: true`
- File upload sans validation MIME + magic bytes + path sanitization
- MCP tools exposed sans rate limit + audit log
- IRI scalar leak (réponse JSON contient un `id: 42` au lieu d'IRI)
- `gen_id: true` sur surface admin (information leak)

**Output verbatim** :

```markdown
## AppSec findings (preserve verbatim — COORDINATOR: include this block as-is)

| # | Risque | Frontière | Acteur | Mitigation | Verdict |
|---|--------|-----------|--------|------------|---------|
| H1 | SSRF via URL preview de webhook | HTTP outbound | authenticated low-priv | allow-list + bloc 169.254.169.254 | **bloque le merge** |
| M1 | Mass assignment via JSON-LD denorm | HTTP boundary | authenticated low-priv | groupes explicites + Voter property | non bloquant si groupes OK |

_COORDINATOR: reproduire ce tableau verbatim. Ne pas paraphraser._
```

---

### 👑 `api-platform-implementer` (renommé de `api-platform-builder`)

**Stage** : Dev.

**Rôle** : implémente le plan dans le repo. Lit le plan, écrit le code, lance les tests, produit le report.

**Hard rules spécifiques** :
- Première action : `Read .claude/last-api-plan.md` (state file)
- Vérifier l'authority order : `<project>:X` exists ? Préférer-le.
- Skill dispatch verification : toute mention "j'ai utilisé X" doit avoir un Skill / Task call correspondant
- BackedEnum natif pour status (jamais free `string`)
- IRI-only sur les relations DTO
- Pas de `#[ApiFilter]` ; toujours `parameters: [QueryParameter]` 4.3
- Tests AC × scenario complets (matrix de l'architect)
- Run réellement les routes touchées dans le browser ou via curl

**Definition of done** (10 items) :
1. `phpunit --filter=Api` vert
2. PHPStan niveau 9+ vert
3. Couverture > 90% sur le diff (recommandé 100% domain)
4. Profondeur du plan implémentée intégralement (aucun trim silencieux)
5. Performance & discoverability au moment où (cacheHeaders, sitemap, etc.)
6. Doc touchée si nouveau type indexable
7. Observability (logs structurés)
8. Rollback path documenté
9. Feature **réellement** exercée (curl ou browser)
10. Anti-patterns API Platform 4.3 checklist Y/N

---

### 🧪 `symfony-tdd-coach` (enrichi)

**Stage** : Test.

**Rôle** : valide tests contre la matrix architect. Anti-tautologie doctrinal.

**Workflow gold-standard** :
1. Read `.claude/last-api-plan.md` + extraire test matrix
2. Read `.claude/last-api-dev-report.md` + identifier classes touchées
3. `phpunit --filter=Api` itérer jusqu'à green
4. `./vendor/bin/infection` (sur le diff)
5. Pour chaque mutant escapé sur chemin critique : Write killing test
6. AC → test → status checklist couvre TOUTE la matrix
7. Émettre rapport entre `===API-TEST-BEGIN===` / `===API-TEST-END===`

**Anti-tautologie** :
- Test qui passe AVEC et SANS le code de prod = tautologie (mutation testing l'attrape)
- Test qui ré-asserte ce que la méthode vient de calculer
- Test sans mapping vers un AC du plan

**Forbid the punt** : "recommend follow-up" sur chemin critique = REJECT auto. Kill ou reject.

**Forbid trust-of-Dev-number** : re-run Infection toi-même, jamais juste citer le chiffre du dev report.

---

### 🗝️ `symfony-reviewer` (enrichissement majeur)

**Stage** : Review.

**Rôle** : gatekeeper. Dernière ligne de défense avant merge. Le pipeline ship du code AI sans review humaine forcément ; le reviewer EST la review.

**Pré-actions obligatoires** :
1. Read `.claude/last-api-plan.md` (référentiel AC + test matrix)
2. Read `.claude/last-api-dev-report.md`
3. Read `.claude/last-api-test-report.md`
4. `git diff --stat` (size check)
5. Si diff > 50 lignes ou touche du code : dispatch skill `review` ET sub-agent `symfony-reviewer` plugin (si différent de soi-même — sinon Skill review)

**Diff classification preamble** :

```
**Diff type:** code | docs | config | mixed
**API Platform area:** resource | filter | provider | processor | security | versioning | mcp | mutator | upgrade | other
**Operation type:** new endpoint | refactor | migration | bug-fix | hardening
**Surface:** internal | public
```

**`===EVIDENCE===` block obligatoire avant verdict** :

```
===EVIDENCE===
- Skills dispatched: gerard:api-platform-filters (3 findings), gerard:api-platform-security (clean)
- Diff inspected: 12 files, +340/-58 lines
- Commands run: phpstan analyse, phpunit --filter=Api
- State files read: last-api-plan, last-api-dev-report, last-api-test-report
===EVIDENCE-END===
```

**API Platform 4.3 anti-patterns checklist embarquée** : 16 patterns issus de `docs/symfony/api-platform-anti-patterns.md`. Voir `agents/symfony-reviewer.md` pour la liste complète.

**Symfony 7.4+ anti-patterns** : `// TODO`, `// FIXME`, `@phpstan-ignore` sans reason, `mixed` dans signature publique, etc.

**Cap unverified claims** : tout claim "j'ai run X" / "vérifié Y" doit avoir un tool call correspondant dans CETTE session. Sinon "le test stage report dit X" (relayed, pas first-hand).

**Skill-theatre detection** : mention "j'ai dispatché X" sans Task/Skill call correspondant dans le tool stream = REQUEST_CHANGES auto.

**Verdict strict** :
- Première ligne non vide = exactement `VERDICT: APPROVE` ou `VERDICT: REQUEST_CHANGES`
- Sur APPROVE : section `**Out of scope for this review:**` obligatoire

---

### 📐 `doctrine-architect` (existant, hors pipeline)

**Stage** : Utility.

**Rôle** : pré-architecture pour les designs d'entités complexes. Pas dans le pipeline `/api-resource-*` (qui assume que les entités sont déjà conçues ou les conçoit en passant).

**Quand le dispatcher** :
- Avant `/architect` quand la story implique de nouvelles entités complexes ou des relations cross-context
- Standalone via `Task(subagent_type="doctrine-architect", ...)`

**Read-only**, propose, n'édite pas.

---

## Tableau de référence — quel agent dispatcher quand

| Besoin | Agent |
|---|---|
| Designer une feature API Platform (resource + opérations + filters + tests) | `api-platform-architect` (via `/architect`) |
| Challenger un plan API Platform (KISS push-back) | `api-platform-aligned-reviewer` (co-dispatché avec architect) |
| Threat model + OWASP findings sur un plan | `api-platform-appsec` (co-dispatché) |
| Implémenter un plan API Platform | `api-platform-implementer` (via `/dev`) |
| Valider tests contre matrix + kill mutants | `symfony-tdd-coach` (via `/test`) |
| Review final + gatekeeper | `symfony-reviewer` (via `/review`) |
| Design d'entités Doctrine complexes (pré-architecture) | `doctrine-architect` |

## Voir aussi

- [`pipeline-overview.md`](pipeline-overview.md) — mermaid des stages
- [`state-files-protocol.md`](state-files-protocol.md) — `.claude/last-api-*.md`
- [`marker-protocol.md`](marker-protocol.md) — `===STAGE-BEGIN===`
- [`project-skills-pattern.md`](project-skills-pattern.md) — `<project>:X` overrides
- [`forensic-audit-template.md`](forensic-audit-template.md) — V1→V2 pattern
