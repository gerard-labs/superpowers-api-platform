# Marker protocol

> Format `===STAGE-BEGIN===` / `===STAGE-END===` consommé par les slash commands.
> Mode vibecode host only.

## Pourquoi

Les sub-agents Task-callable retournent du markdown. Le coordinator slash command doit **extraire de manière fiable** la portion exploitable du retour pour l'écrire dans le state file. Les markers permettent un parsing déterministe (vs essayer de deviner les bornes).

## Markers définis

| Stage | Marker BEGIN | Marker END | Écrit dans |
|---|---|---|---|
| Architecture | `===API-PLAN-BEGIN===` | `===API-PLAN-END===` | `.claude/last-api-plan.md` |
| Dev | `===API-DEV-BEGIN===` | `===API-DEV-END===` | `.claude/last-api-dev-report.md` |
| Test | `===API-TEST-BEGIN===` | `===API-TEST-END===` | `.claude/last-api-test-report.md` |
| Review evidence | `===EVIDENCE===` | `===EVIDENCE-END===` | inline dans `last-api-review.md` |
| Review verdict | `===API-REVIEW-BEGIN===` | `===API-REVIEW-END===` | `.claude/last-api-review.md` |

## Règles d'utilisation

### Pour les sub-agents

Chaque agent qui produit un report **encadre son output** entre les markers de son stage. Exemple pour `api-platform-implementer` :

```
===API-DEV-BEGIN===
## Ce qui a changé

Adds CSV export endpoint on /api/tenders/export.csv with async Mercure progress.

## Files touched

- src/ApiResource/TenderExportResource.php
- src/Dto/CreateTenderExportInput.php
- src/State/CreateTenderExportProcessor.php
- tests/Functional/Api/TenderExportTest.php
- ...

## Anti-patterns API Platform 4.3 checklist Y/N

- [x] No #[ApiFilter] used (parameters: [QueryParameter] modern pattern)
- [x] No openapiContext (openapi: new Model\\Operation(...))
- [x] IRI-only on relations
- [x] BackedEnum for statuses
- [x] No mixed in public signatures
- ...

===API-DEV-END===
```

### Pour les coordinator slash commands

Le coordinator extrait simplement le contenu **entre les markers** et l'écrit dans le state file :

```
/dev coordinator (pseudo) :
1. Read .claude/last-api-plan.md
2. Task(api-platform-implementer, ...) → returns report
3. Extract content between ===API-DEV-BEGIN=== and ===API-DEV-END===
4. Write .claude/last-api-dev-report.md with extracted content
5. Output to user: "Dev done, run /test next"
```

### Pour le verdict

Le verdict review a une règle **strictement** plus stricte : la **première ligne non vide** entre `===API-REVIEW-BEGIN===` et `===API-REVIEW-END===` est **exactement** :

```
VERDICT: APPROVE
```

OU

```
VERDICT: REQUEST_CHANGES
```

Aucun modificateur (`VERDICT: APPROVE WITH CAVEATS`), aucun préfixe (`# VERDICT: APPROVE`), aucun emoji. Format machine-parseable strict.

Le coordinator `/api-resource-pipeline` et `/api-resource-ship` parse cette ligne pour décider :
- `APPROVE` → exit loop, stop (pipeline) ou commit (ship)
- `REQUEST_CHANGES` → re-run `/dev` (iter++) ou escalation si iter > 3

## Evidence block (review)

Avant le verdict, le reviewer émet un `===EVIDENCE===` block pour rendre la décision auditable :

```
===EVIDENCE===
- Skills dispatched: gerard:api-platform-filters (3 findings — all resolved), gerard:api-platform-security (clean)
- Diff inspected: 12 files, +340/-58 lines
- Commands run: phpstan analyse (0 errors), phpunit --filter=Api (148 tests, 502 assertions, all pass)
- State files read: last-api-plan, last-api-dev-report, last-api-test-report
- API Platform anti-patterns checklist: 16/16 pass
===EVIDENCE-END===
```

Le coordinator inclut ce block dans `.claude/last-api-review.md` (pas séparé).

## Verbatim preservation dans la synthèse architecture

Le coordinator `/architect` synthétise 3 personas mais **préserve verbatim** les blocs marqués :

```markdown
## Aligned-Reviewer note (preserve verbatim)

**Agreements:** ...
**Trims:** ...
...

## AppSec findings (preserve verbatim — COORDINATOR: include this block as-is)

| # | Risque | ... |
| H1 | ... |
```

Le coordinator **n'a pas le droit** de paraphraser, condenser ou retirer ces blocs. Ils traversent intacts jusqu'au state file `last-api-plan.md` puis sont lus par `symfony-reviewer` au stage Review.

## Anti-patterns

- ❌ Sub-agent qui oublie d'encadrer son output → coordinator ne peut pas extraire fiablement
- ❌ Marker mal orthographié (`===API-DEV-BEGIN ===` avec espace) → extraction échoue
- ❌ Coordinator qui sauve **tout** le retour de l'agent au lieu de juste le contenu marqué → state file pollué
- ❌ Verdict qui commence par autre chose que `VERDICT:` (e.g. `**VERDICT: APPROVE**` Markdown) → parser cassé
- ❌ Verdict avec modificateur (`APPROVE WITH CAVEATS`) → considéré APPROVE par défaut ; ambigu

## Voir aussi

- [`state-files-protocol.md`](state-files-protocol.md) — où les markers sont consommés
- [`agentic-personas.md`](agentic-personas.md) — quels agents émettent quels markers
- [`pipeline-overview.md`](pipeline-overview.md) — séquence complète
