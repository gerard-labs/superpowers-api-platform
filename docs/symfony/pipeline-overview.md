# Pipeline overview (vibecode host)

> **Mode**: vibecode host only. `claude` lancé localement, slash commands drivent les stages.

## Vue d'ensemble

7 agents Task-callable + 7 slash commands de pipeline (en plus des skills classiques). Le pipeline staged peut être invoqué stage-par-stage ou en chain via `/api-resource-pipeline` (semi-auto) / `/api-resource-ship` (full auto avec commit + push + PR).

```mermaid
flowchart TB
    User[User: claude depuis le repo] --> Mode{Stratégie}

    Mode -->|atomique| Single[Skill ou agent direct]
    Mode -->|pipeline semi-auto| Pipe[/api-resource-pipeline story/]
    Mode -->|pipeline full auto| Ship[/api-resource-ship story/]

    Single --> Direct[Skill: gerard:api-platform-filters<br/>ou agent: api-platform-implementer]

    subgraph FullPipeline[Pipeline 4 stages + loop cap 3]
        direction TB
        Arch[/architect/]
        Dev[/dev/]
        Test[/test/]
        Review[/review/]
        Arch --> Dev --> Test --> Review
        Review -->|REQUEST_CHANGES| Dev
        Review -->|APPROVE| Done
    end

    Pipe --> FullPipeline
    Ship --> FullPipeline
    FullPipeline --> Done{Verdict}

    Done -->|APPROVE & pipeline| Stop[STOP — user commits]
    Done -->|APPROVE & ship| Commit[Compose + add + commit + push + PR]
    Done -->|REQUEST_CHANGES iter>3| Esc[ESCALATION]

    style Esc fill:#ffebee,stroke:#c62828
    style Stop fill:#e3f2fd,stroke:#1976d2
    style Commit fill:#e8f5e9,stroke:#2e7d32
```

## Les 4 stages en détail

### Architecture stage (`/architect`)

3 personas dispatchés en parallèle, synthèse avec préservation verbatim.

```mermaid
sequenceDiagram
    participant User
    participant Coord as /architect coordinator
    participant Arch as api-platform-architect
    participant Align as api-platform-aligned-reviewer
    participant Sec as api-platform-appsec
    participant FS as Filesystem

    User->>Coord: /architect "Add CSV export to TenderResource"
    Coord->>Coord: Detect API Platform area (resource/filter/provider/etc.)
    Coord->>Arch: Task: design the resource + operations + filters + test matrix
    Arch-->>Coord: Plan markdown (9 sections)
    Coord->>Align: Task: KISS push-back (IRI-only, Object Mapper, BackedEnum, etc.)
    Align-->>Coord: Aligned-Reviewer note (Trims/Smallest slice/Scope guard) — verbatim
    Coord->>Sec: Task: OWASP findings (voter bypass, IDOR, IRI leak, CORS, JWT, MCP)
    Sec-->>Coord: AppSec findings table — verbatim
    Coord->>Coord: Synthesize PRESERVING verbatim blocks
    Coord->>FS: Write .claude/last-api-plan.md
    Coord-->>User: Plan ready, run /dev next
```

### Dev stage (`/dev`)

Un seul persona, `api-platform-implementer`, lit le plan et code.

```mermaid
sequenceDiagram
    participant User
    participant Coord as /dev coordinator
    participant Impl as api-platform-implementer
    participant FS as Filesystem
    participant Bash as bin/console + phpunit

    User->>Coord: /dev
    Coord->>FS: Read .claude/last-api-plan.md
    Coord->>Impl: Task: implement (plan + API Platform area)
    Impl->>Impl: Detect API Platform area + project skills overrides
    Impl->>FS: Write/Edit source files (resource, DTO, provider, processor, tests)
    Impl->>Bash: phpunit --filter=Api (iterate green)
    Impl->>Bash: php bin/console api:openapi:export --yaml (sanity)
    Impl-->>Coord: ===API-DEV-BEGIN===…===API-DEV-END===
    Coord->>FS: Write .claude/last-api-dev-report.md
    Coord-->>User: Dev done, run /test next
```

### Test stage (`/test`)

`symfony-tdd-coach` lit la test matrix de l'architecte et valide AC × test mapping.

```mermaid
sequenceDiagram
    participant User
    participant Coord as /test coordinator
    participant Coach as symfony-tdd-coach
    participant FS as Filesystem
    participant Bash as phpunit + Infection

    User->>Coord: /test
    Coord->>FS: Read last-api-plan.md + last-api-dev-report.md
    Coord->>Coach: Task: validate tests against architect matrix
    Coach->>FS: Read plan (extract test matrix)
    Coach->>Bash: phpunit --filter=Api (iterate green)
    Coach->>Bash: ./vendor/bin/infection
    Bash-->>Coach: Mutation results + escapees
    loop Each killable mutant on critical path
        Coach->>FS: Write killing test
        Coach->>Bash: re-run mutation
    end
    Coach->>Coach: AC → test → status checklist (anti-tautology)
    Coach-->>Coord: ===API-TEST-BEGIN===…===API-TEST-END===
    Coord->>FS: Write .claude/last-api-test-report.md
    Coord-->>User: Tests done, run /review next
```

### Review stage (`/review`)

`symfony-reviewer` est le gatekeeper. Il dispatche d'abord la skill `review` puis évalue.

```mermaid
sequenceDiagram
    participant User
    participant Coord as /review coordinator
    participant Rev as symfony-reviewer
    participant FS as Filesystem

    User->>Coord: /review
    Coord->>FS: Read last-api-plan + last-api-dev-report + last-api-test-report
    Coord->>Rev: Task: review the diff against API Platform 4.3 anti-patterns
    Rev->>Rev: Classify diff (code/docs/config × API Platform area × surface)
    Rev->>Rev: Apply API Platform 4.3 + Symfony 7.4+ anti-patterns checklist
    Rev->>Rev: Cap unverified claims + skill-theatre detection
    alt All checks pass
        Rev-->>Coord: VERDICT: APPROVE + Out of scope section
    else Any check fails
        Rev-->>Coord: VERDICT: REQUEST_CHANGES + numbered list
    end
    Coord->>FS: Write .claude/last-api-review.md
    Coord-->>User: Verdict ready
```

## State machine (vibecode host)

```mermaid
stateDiagram-v2
    [*] --> draft
    draft --> architected: /architect
    architected --> coded: /dev
    coded --> tested: /test
    tested --> reviewed: /review
    reviewed --> shipped: VERDICT: APPROVE → commit + push
    reviewed --> coded: VERDICT: REQUEST_CHANGES (iter <= 3)
    reviewed --> escalation: VERDICT: REQUEST_CHANGES (iter > 3)
    shipped --> [*]
    escalation --> [*]
```

En mode `/api-resource-pipeline` / `/api-resource-ship`, le coordinator implémente cette state machine côté slash command (cap dur de 3 itérations).

## Composition prompts (mode host)

Pas de `--append-system-prompt`, pas de `--agents` JSON. Tout passe par les fichiers `.claude/` et les `@import` Claude Code :

```mermaid
flowchart TB
    CCMD[CLAUDE.md du projet consumer] -.optional @import.-> Personas[.claude/system-persona.md / design-system-floor.md]
    Plugin[Plugin gerard via marketplace] --> Agents[.claude/agents/*.md du plugin]
    Plugin --> Commands[.claude/commands/*.md du plugin]
    Plugin --> Skills[skills/*/SKILL.md du plugin]

    User[Dev tape /api-resource-pipeline story] --> Commands
    Commands -->|dispatche via Task| Agents
    Agents -->|invoque via Skill / Task| Skills

    ProjectSkills[Project local: .claude/skills/<project>/*.md] -.override priorité.-> Skills

    style ProjectSkills fill:#e3f2fd,stroke:#1976d2
    style Plugin fill:#e8f5e9,stroke:#2e7d32
```

## Authority order

Voir `agentic-personas.md` pour l'application aux agents.

```
1. Project CLAUDE.md           ← Hard Rules locales du projet consumer
2. Stage personas              ← agents dispatchés par stage
3. Project skills layer         ← <project>:X overrides gerard:X
4. Plugin canonical skills      ← gerard:* (canon API Platform 4.3 + Symfony 7.4+)
```

## Garde-fous

| Garde-fou | Source |
|---|---|
| Cap REQUEST_CHANGES | Cap dur de 3 dans `/api-resource-pipeline` et `/api-resource-ship` |
| Refus sur dirty tree | Pre-flight `/api-resource-ship` |
| Toujours feature branch | Pre-flight `/api-resource-ship` |
| `--no-verify` denied | Recommandé dans le `.claude/settings.json` du projet consumer |
| `--force` denied | Idem |
| Explicit `git add` | Coordinator `/api-resource-ship` |
| Skip `.env`, `*.local.*`, `*.pem`, `*.key` | Coordinator `/api-resource-ship` |
| Marker required | Coordinator écrit dans `.claude/last-api-*.md` |
| Verdict strict | Première ligne non vide = exactement `VERDICT: APPROVE` ou `VERDICT: REQUEST_CHANGES` |

## Voir aussi

- [`agentic-personas.md`](agentic-personas.md) — détail des 7 agents
- [`state-files-protocol.md`](state-files-protocol.md) — convention `.claude/last-api-*.md`
- [`marker-protocol.md`](marker-protocol.md) — format `===STAGE-BEGIN===`
- [`project-skills-pattern.md`](project-skills-pattern.md) — couche skills projet local
- [`forensic-audit-template.md`](forensic-audit-template.md) — pattern ship → measure → tighten
- [`api-platform-anti-patterns.md`](api-platform-anti-patterns.md) — checklist embarquée dans `symfony-reviewer`
