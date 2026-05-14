# Project skills pattern

> Comment un projet consumer du plugin peut ajouter sa **doctrine locale** par-dessus le canon `gerard:*` du plugin.

## Pourquoi

Le plugin `gerard` ship un canon **API Platform 4.3 + Symfony 7.4+** valide pour 90% des projets. Mais chaque projet a sa **doctrine propre** :
- Form contract spécifique (codifié FC1-FC11 ou similaire selon le projet)
- Theming system (light/dark + accents) propre au design system
- Conventions i18n
- Surface conventions (admin / public / mobile-only)

Le plugin **n'impose pas** ces conventions. Il offre un canon, et le projet peut **override** ou **étendre** via une couche locale.

## Structure recommandée

```
your-project/
├── CLAUDE.md                          # tes Hard Rules projet
├── .claude/
│   ├── settings.json                  # enabledPlugins: gerard
│   ├── skills/
│   │   └── <project-name>/            # ⭐ ta doctrine locale
│   │       ├── form-contract/
│   │       │   └── SKILL.md
│   │       ├── theming/
│   │       │   └── SKILL.md
│   │       ├── i18n-routing/
│   │       │   └── SKILL.md
│   │       └── ...
│   ├── agents/
│   │   └── ...                        # tes agents projet (optionnel)
│   └── commands/
│       └── ...                        # tes commandes projet (optionnel)
```

## Naming convention

Préfixe **non-`gerard`** pour les skills projet. Convention recommandée :

```yaml
---
name: <project-name>:form-contract
description: Project-specific form contract (FC1-FC11). Overrides any equivalent gerard:* skill.
---
```

Exemple : un projet `myapp` peut déclarer `myapp:form-contract`, `myapp:turbo-doctrine`, `myapp:component-library`, etc.

## Authority order — comment les agents arbitrent

Chaque agent du plugin a une **section commune** dans son prompt :

```
## Authority order — local skill overrides

Avant de dispatcher un skill `gerard:X`, vérifie via Glob si un override projet
existe à `.claude/skills/<project-name>/X/SKILL.md`. Si oui, dispatch
`<project>:X` en priorité (la doctrine projet override le canon plugin).

Le canon plugin `gerard:*` reste la référence quand aucun override n'existe.
```

Concrètement :

```
api-platform-implementer va éditer un form. Workflow :
1. Glob: .claude/skills/*/form-contract/SKILL.md
   → trouve myapp/form-contract/SKILL.md
2. Skill: myapp:form-contract (priorité)
   → lit la doctrine FC1-FC11 du projet
3. Implémente le form selon la doctrine projet
4. Si la skill projet pointe vers gerard:form-types-validation, descend au plugin
```

```
api-platform-implementer va éditer un filter. Workflow :
1. Glob: .claude/skills/*/api-platform-filters/SKILL.md
   → rien trouvé
2. Skill: gerard:api-platform-filters (canon plugin)
3. Implémente avec parameters + QueryParameter (4.3 modern pattern)
```

## Override partiel — référencer le canon

Une skill projet peut **étendre** le canon plutôt que de le remplacer entièrement :

```markdown
---
name: myproject:api-platform-filters
description: Project-specific filter conventions ON TOP of gerard:api-platform-filters
---

# My Project — API Platform filters

> **Important**: ce skill **complète** `gerard:api-platform-filters` du plugin
> symfony. Read it first for the canon 4.3 pattern, then apply
> these project-specific rules:

## Project-specific rules

1. Tous les filters de pagination doivent utiliser `UuidFilter` (UUIDv7 standard du projet)
2. Tous les ranges de date doivent passer par notre `BusinessDayFilter` custom
3. Sort filters limités à 3 champs par opération max (perf budget)

## Default
Voir `gerard:api-platform-filters` pour les patterns 4.3 standards.
```

Pattern : **toujours référencer le canon plugin** quand on l'override partiellement. Évite la duplication et le drift.

## Skills projet hors API Platform

La couche projet peut aussi définir des skills qui **n'existent pas du tout** dans le plugin :

- `myapp:form-contract` (FC1-FC11)
- `myapp:turbo-doctrine` (T1-T8)
- `myapp:component-library`
- `myapp:csp-strict-dynamic`
- `myapp:custom-domain-events`
- ...

Ces skills sont **purement projet** et n'ont pas d'équivalent canon. Les agents les dispatchent quand le contexte l'exige (la skill projet déclare ses triggers dans sa `description`).

## Agents projet (optionnel)

Un projet peut aussi ajouter ses propres agents dans `.claude/agents/<project>-<agent>.md`. Ils s'ajoutent à ceux du plugin.

Exemple : un agent `myproject-frontend-builder` qui dispatche les skills `myproject:component-library` + `myproject:turbo-doctrine` pour le frontend.

## CLAUDE.md du projet — la source d'autorité ultime

`CLAUDE.md` est **toujours** au-dessus de tout (autorité #1 dans l'ordre). Le projet y déclare :
- Hard Rules locales (PHP version, framework version, namespaces, etc.)
- Stack spécifique (e.g. monorepo avec 3 sub-projects → scope detection custom)
- Liens vers les skills projet (avec `@import` ou simple référence prose)
- Référence au plugin gerard (autorité #4)

Exemple `CLAUDE.md` minimaliste qui consume le plugin :

```markdown
# Project — CLAUDE.md

## Stack
- Symfony 7.4
- API Platform 4.3
- PHP 8.4
- PostgreSQL 16

## Architecture
- Bounded contexts: Identity, Marketing, Workspace, Shared
- DDD + Hexagonal — Deptrac enforced
- CQRS via Symfony Messenger

## Authority order
1. Ce fichier (Hard Rules projet)
2. Project skills layer: `.claude/skills/myproject/*.md` (FC1-FC11, theming, etc.)
3. Plugin `gerard` (canon API Platform 4.3 + Symfony 7.4+)

## Project skills (override priorities)
- `myproject:form-contract` — FC1-FC11 (override `gerard:form-types-validation`)
- `myproject:theming` — light/dark × 5 accents

## Voir aussi
- [`.claude/skills/myproject/`](./.claude/skills/myproject/) — doctrine projet
- Plugin: github.com/gerard-labs/superpowers-api-platform
```

## Anti-patterns

- ❌ Skill projet sans naming `<project>:X` (utilise le préfixe `gerard:`) → collision avec le plugin
- ❌ Skill projet qui duplique tout le canon (copier-coller) — utiliser le pattern "extend with override partiel"
- ❌ Agents projet qui ignorent le canon plugin → réinventer la roue, perdre les mises à jour
- ❌ CLAUDE.md projet qui ne mentionne pas le plugin → autres devs ne savent pas que le canon plugin existe

## Voir aussi

- [`agentic-personas.md`](agentic-personas.md) — section "Authority order — implémentation par les agents"
- [`pipeline-overview.md`](pipeline-overview.md) — où ces overrides interviennent dans le pipeline
