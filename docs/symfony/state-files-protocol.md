# State files protocol (`.claude/last-api-*.md`)

> Convention pour le handoff entre stages du pipeline `/api-resource-*`.
> Mode vibecode host only — pas de PHP server-side, pas d'extraction côté orchestrateur.

## Les 4 fichiers

| Fichier | Stage qui l'écrit | Stages qui le lisent | Contenu |
|---|---|---|---|
| `.claude/last-api-plan.md` | `/architect` | `/dev`, `/test`, `/review` | Plan synthétisé (9 sections + verbatim Aligned-Reviewer + AppSec findings) |
| `.claude/last-api-dev-report.md` | `/dev` | `/test`, `/review` | Report d'implémentation (files touched + ce qui a changé + skills dispatchées + résultats CI) |
| `.claude/last-api-test-report.md` | `/test` | `/review` | Report de tests (AC × test mapping + mutation results + classes critiques MSI) |
| `.claude/last-api-review.md` | `/review` | `/api-resource-pipeline`, `/api-resource-ship` | Verdict (APPROVE / REQUEST_CHANGES + rationale + Out of scope) |

## Flow

```mermaid
flowchart LR
    subgraph FS[Filesystem .claude/]
        P[last-api-plan.md]
        D[last-api-dev-report.md]
        T[last-api-test-report.md]
        R[last-api-review.md]
    end

    Arch[/architect/] -->|écrit| P
    P -->|lit| Dev[/dev/]
    Dev -->|écrit| D
    P -->|lit| Test[/test/]
    D -->|lit| Test
    Test -->|écrit| T
    P -->|lit| Review[/review/]
    D -->|lit| Review
    T -->|lit| Review
    Review -->|écrit| R
    R -->|lit| Loop[/api-resource-pipeline ou ship]
```

## Caractéristiques

### 1. Gitignorés

Les fichiers `.claude/last-api-*.md` sont **state runtime**, pas du source code. Ils sont ajoutés au `.gitignore` du plugin :

```gitignore
.claude/last-api-*.md
```

Un projet consumer hérite naturellement de cette convention en clonant `.gitignore` du plugin ou en ajoutant cette ligne.

### 2. Survivent à fermeture de session

Permet de **rejouer** un stage isolément :
- "Le `/review` a buggé, je relance `/review` sans re-faire `/architect /dev /test`"
- "Je veux inspecter le dernier plan sans le pipeline complet : `Read .claude/last-api-plan.md`"

### 3. Auditables

Les fichiers contiennent les sorties markers (`===API-PLAN-BEGIN===` etc.) — voir [`marker-protocol.md`](marker-protocol.md). Ce qui permet à un humain ou à un outil de **rejouer** ou **diff-er** entre runs.

### 4. Écrasés à chaque pipeline

`/architect` écrase `last-api-plan.md` à chaque run. Pas d'historisation interne — c'est `git log` qui historise via les PRs.

Si tu veux conserver le plan d'un pipeline particulier (debug), copie-le manuellement :

```bash
cp .claude/last-api-plan.md docs/history/2026-05-11-add-csv-export-plan.md
```

## Convention de coordination entre stages

### Étape 1 — Stage écrit son state file

Chaque coordinator slash command écrit le state file **après** que le sub-agent retourne :

```
/dev coordinator:
1. Read .claude/last-api-plan.md
2. Task: api-platform-implementer (avec le plan en input)
3. Sub-agent retourne ===API-DEV-BEGIN===…===API-DEV-END===
4. Write .claude/last-api-dev-report.md avec le contenu entre les markers
5. Output: "Dev done, run /test next"
```

### Étape 2 — Stage suivant lit le state file

```
/test coordinator:
1. Read .claude/last-api-plan.md (pour la test matrix)
2. Read .claude/last-api-dev-report.md (pour identifier les classes touchées)
3. Task: symfony-tdd-coach
4. Write .claude/last-api-test-report.md
```

### Étape 3 — Review reçoit tout le contexte

```
/review coordinator:
1. Read les 3 fichiers .claude/last-api-*.md
2. Task: symfony-reviewer (avec tous les contextes)
3. Write .claude/last-api-review.md
```

### Étape 4 — Loop / commit

Le coordinator `/api-resource-pipeline` ou `/api-resource-ship` lit `.claude/last-api-review.md`, parse la première ligne :
- `VERDICT: APPROVE` → suite (stop ou commit)
- `VERDICT: REQUEST_CHANGES` → re-run `/dev` (iter++)
- Cap 3 itérations → escalation

## Anti-patterns

- ❌ Sauter une lecture de state file ("je sais ce qu'il y a dedans"). Toujours `Read`.
- ❌ Modifier un state file directement (`Edit`) — c'est runtime, pas source.
- ❌ Commiter un state file. Le `.gitignore` empêche, mais c'est rappelé ici.
- ❌ Faire confiance au state file d'un précédent pipeline complètement différent. Si tu lances `/architect` avec une story différente, `/dev` doit re-Read le nouveau plan.

## Convention de nommage

Les state files sont préfixés `-api-` pour ne pas collisionner si un projet consumer mixe notre plugin avec un autre workflow déclarant aussi des `.claude/last-*.md`.

| State file | Stage |
|---|---|
| `.claude/last-api-plan.md` | Architecture |
| `.claude/last-api-dev-report.md` | Dev |
| `.claude/last-api-test-report.md` | Test |
| `.claude/last-api-review.md` | Review |

## Voir aussi

- [`marker-protocol.md`](marker-protocol.md) — format des markers à extraire
- [`pipeline-overview.md`](pipeline-overview.md) — séquence complète
- [`agentic-personas.md`](agentic-personas.md) — qui écrit / qui lit
