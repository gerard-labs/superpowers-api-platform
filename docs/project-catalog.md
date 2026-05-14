# Project Catalog — API Platform 4.3 starter shapes

Three canonical project shapes the plugin supports. Pick the closest to your context, then read the linked skill clusters.

## Shape 1 — Public REST/JSON-LD API (most common)

**Surface**: external partners or web/mobile clients consume the API.

**Stack** :
- API Platform 4.3 + Symfony 7.4+ + Doctrine ORM + PostgreSQL
- JWT (LexikJWTAuthenticationBundle) or OIDC (Keycloak / Auth0)
- FrankenPHP worker mode (production)
- Mercure (optional, for real-time)

**Skills cluster** :
- Foundation: `api-platform-resources`, `api-platform-dto-resources`, `api-platform-state-providers`, `api-platform-state-processors`
- Filters/pagination: `api-platform-filters`, `api-platform-pagination`
- Security: `api-platform-security`, `api-platform-user`, `symfony-voters`, `rate-limiting`
- Identifiers: `api-platform-identifiers` (UUID v7 strongly recommended for public IDs)
- Performance: `api-platform-performance`, `symfony-cache`, `doctrine-fetch-modes`
- Doc: `api-platform-openapi` (Scalar UI for partner-facing doc)
- Tests: `api-platform-tests` (ApiTestCase + DAMA + Foundry + ParaTest)

**Pipeline command** : `/api-resource-pipeline <story>` (recommended) or `/api-resource-ship <story>` (autonomy).

---

## Shape 2 — Internal admin API (back-office)

**Surface**: internal staff via admin UI (Symfony UX Live Components / Stimulus / Turbo) or external admin SPA.

**Stack** :
- API Platform 4.3 + Symfony 7.4+
- Built-in Swagger UI / Scalar for the team
- Doctrine + PostgreSQL
- Symfony Voters everywhere

**Skills cluster** :
- Foundation as Shape 1, but typically simpler (less DTO-versioning, less SEO)
- Security: heavy voter use, possibly `#[ApiProperty(security: ...)]` for admin-only fields
- Errors: `api-platform-errors` for `#[ErrorResource]` modeling
- No public surface → skip SEO/GEO / sitemap / `llms.txt`

**Pipeline command** : `/api-resource-pipeline <story>` (full auto rarely justified for admin).

---

## Shape 3 — Headless platform with AI integration (MCP)

**Surface**: API consumed by AI agents (Claude, ChatGPT, internal LLM workflows) **in addition to** human/web clients.

**Stack** :
- API Platform 4.3 with **MCP integration** (`api-platform/mcp` + `symfony/mcp-bundle`)
- Rate limiting + audit log on `/mcp`
- All public endpoints exposed as REST + as MCP tools

**Skills cluster** :
- Shape 1 stack
- Plus: `api-platform-mcp` (mandatory)
- Plus: dedicated `rate-limiting` configuration for `/mcp`
- Plus: `api-platform-resilience` (since agents can hammer the API)

**Caution** : MCP is `@experimental` in 4.3. Pin the exact version. Restrict tool exposure (no destructive Delete without explicit confirmation flow).

**Pipeline command** : `/api-resource-pipeline` for each MCP-exposed operation.

---

## Decision tree

```
Does the API have external consumers (partners, clients) ?
├── Yes → Shape 1 (Public)
└── No  → Internal-only ?
          ├── Admin UI only       → Shape 2 (Admin)
          └── AI agents involved  → Shape 3 (MCP)
```

## See also

- [`complexity-tiers.md`](complexity-tiers.md) — sizing inside a chosen shape
- [`project-examples.md`](project-examples.md) — concrete examples per shape
- [`symfony/pipeline-overview.md`](symfony/pipeline-overview.md) — how the pipeline orchestrates the cluster
- [`symfony/agentic-personas.md`](symfony/agentic-personas.md) — the 7 agents
