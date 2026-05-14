---
name: api-platform-mcp
description: Expose API Platform 4.3 operations as Model Context Protocol tools for AI agents (Claude, ChatGPT, etc.) via the new `api-platform/mcp` + `symfony/mcp-bundle` components — marked `@experimental` upstream. Covers `#[McpTool]` standalone (`name`, `description`, `processor`, optional `validate: true`), the `mcp:` keyword on `#[ApiResource]` (with `operations: []` to disable HTTP routes and expose only as MCP), `McpToolCollection` with `structuredContent: true` for Hydra-aware responses, the `mcp.yaml` configuration (http/stdio transports, session store), JSON Schema override via `#[ApiProperty(schema: …)]` for LLMs that reject union types, and the safety guardrails (pin the version, restrict tools — no destructive Delete without confirmation, audit log, dedicated rate limit on `/mcp`). Trigger on "MCP", "expose API to AI agent", "model context protocol", or "give my Claude tool access to the API".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# API Platform 4.3 — MCP (Model Context Protocol) — `@experimental`

## Use when
- An AI agent (Claude, ChatGPT, Cursor, …) needs to call the API as a tool.
- Specific operations should be exposed only to agents (no HTTP route).
- The agent should consume Hydra-aware structured content for better context.

## Default workflow
1. Install `api-platform/mcp` + `symfony/mcp-bundle` with a **pinned exact version** (`composer require api-platform/mcp:4.3.x`).
2. Configure `mcp.yaml` (transports, session store) and enable in `api_platform.yaml`.
3. Define tools — either standalone with `#[McpTool]`, or on existing resources via the `mcp:` keyword.
4. For collections, use `McpToolCollection(structuredContent: true)`.
5. Enable validation explicitly (`validate: true`) on tools that mutate state.
6. Add audit logging + dedicated rate limiting on `/mcp`.

## Guardrails
- **`@experimental`**: the API surface may change between minor releases. Pin the exact version.
- **Restricted tool set**: expose only tools that are safe for an agent. **No Delete without explicit confirmation flow.**
- **Schema strict**: explicitly declare input schemas via `#[ApiProperty(schema: ...)]` for LLMs that reject union types.
- **Audit log**: trace every MCP call (who, what, when) — an AI agent is not a human user.
- **Rate limiting**: a dedicated limiter on `/mcp` (cf. `gerard:rate-limiting`).
- **No PII leakage**: review every tool's response payload — assume the AI may use it in a prompt that goes to a third party.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full install, configuration, both declaration patterns (`#[McpTool]` standalone and `mcp:` on `#[ApiResource]`), `McpToolCollection`, validation, schema override, and bonnes pratiques.

## Output contract
- A pinned `api-platform/mcp` version.
- Tools declared with `#[McpTool]` and / or via `mcp:` on resources.
- Schemas overridden where needed for LLM compatibility.
- Audit logging configured for `/mcp`.
- Dedicated rate limit on the `/mcp` endpoint.

## References
- `reference.md`
- Upstream: <https://api-platform.com/docs/core/mcp/>
