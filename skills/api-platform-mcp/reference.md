# API Platform 4.3 — MCP (reference)

> 🆕 **API Platform 4.3 — `@experimental`**: `api-platform/mcp` exposes operations as **MCP tools** (Model Context Protocol), an open standard for AI-agent ↔ service interaction.
>
> ⚠️ *"The MCP integration is marked `@experimental`. The API may change between minor releases."*
>
> Source: <https://api-platform.com/docs/core/mcp/>.

## 1. Install

```bash
composer require api-platform/mcp:4.3.* symfony/mcp-bundle
```

**Pin the exact minor** while it's `@experimental` — minor releases may shift the API.

---

## 2. Configuration

```yaml
# config/packages/mcp.yaml
mcp:
    client_transports:
        http:  true
        stdio: false
    http:
        path: '/mcp'
        session:
            store:     'file'
            directory: '%kernel.cache_dir%/mcp'
            ttl:       3600
```

```yaml
# config/packages/api_platform.yaml
api_platform:
    mcp:
        enabled: true
        format:  jsonld   # or json / jsonapi
```

---

## 3. Pattern A — `#[McpTool]` standalone

A standalone tool that lives entirely in the agent surface (no HTTP route).

```php
use ApiPlatform\Mcp\Attribute\McpTool;
use ApiPlatform\Mcp\Result\CallToolResult;
use ApiPlatform\Mcp\Result\TextContent;

#[McpTool(
    name:        'process_message',
    description: 'Process a message with priority',
    processor:   [self::class, 'process'],
)]
final class ProcessMessage
{
    public function __construct(
        public string $message,
        public int    $priority = 1,
    ) {}

    public static function process(self $data): CallToolResult
    {
        // Business logic.
        return new CallToolResult([new TextContent("OK priority {$data->priority}")], false);
    }
}
```

---

## 4. Pattern B — `mcp:` on `#[ApiResource]`

Disable HTTP routes (`operations: []`) and expose the resource only as an MCP tool.

```php
use ApiPlatform\Mcp\Attribute\McpTool;
use ApiPlatform\Metadata\ApiResource;

#[ApiResource(
    operations: [],
    mcp: [
        'read_hydra_resource' => new McpTool(
            description:       'Navigate to a Hydra API resource by URI.',
            processor:         ReadHydraResourceProcessor::class,
            structuredContent: false,
        ),
    ],
)]
class ReadHydraResource
{
    public string $uri;
}
```

---

## 5. Collections — `McpToolCollection`

```php
use ApiPlatform\Mcp\Attribute\McpToolCollection;
use ApiPlatform\Metadata\ApiResource;

#[ApiResource(
    operations: [],
    mcp: [
        'list_books' => new McpToolCollection(
            description:       'List Books',
            input:             SearchQuery::class,
            processor:         SearchBooksProcessor::class,
            structuredContent: true,
        ),
    ],
)]
class Book { /* ... */ }
```

With `structuredContent: true`, the response embeds `@context`, `totalItems`, `member` — compatible with a Hydra-aware consumer.

---

## 6. Validation

**Validation is disabled by default on MCP tools.** Enable explicitly when needed:

```php
new McpTool(
    description: '...',
    processor:   MyProcessor::class,
    validate:    true,   // re-enables Symfony validation
)
```

Always enable for tools that mutate state.

---

## 7. JSON Schema override for sensitive LLMs

Some LLMs reject union types in JSON Schema (`["array", "null"]`). Override the schema explicitly:

```php
#[ApiProperty(schema: ['type' => 'object', 'description' => 'JSON payload'])]
public ?array $payload = null;
```

This produces a single-type schema that every LLM accepts.

---

## 8. Best practices

- **`@experimental`**: pin the exact version (`composer require api-platform/mcp:4.3.x`).
- **Restricted tool set**: expose **only** what is safe for an AI agent. No destructive `Delete` without an explicit confirmation flow.
- **Strict schema**: declare the input schema explicitly via `#[ApiProperty(schema: [...])]` for LLMs that are picky.
- **Audit log**: log every MCP call (who, what, when). An AI agent is not a human user — full traceability is mandatory.
- **Rate limiting** dedicated to `/mcp` (cf. `gerard:rate-limiting`).
- **No PII leakage**: review every tool's response carefully — assume the AI may forward the output to a third party in a prompt.

---

## 9. Security & rate-limit example

```yaml
framework:
    rate_limiter:
        mcp:
            policy: sliding_window
            limit:  60
            interval: '1 minute'
```

```php
# A subscriber or Provider decorator can apply the limiter on /mcp routes.
# Cf. gerard:rate-limiting for the full pattern.
```

```yaml
# config/packages/security.yaml — protect /mcp behind auth
security:
    access_control:
        - { path: ^/mcp, roles: IS_AUTHENTICATED_FULLY }
```

---

## 10. Audit logging

```php
final readonly class McpAuditSubscriber
{
    public function __construct(
        private LoggerInterface $logger,
        private Security $security,
    ) {}

    public function onMcpToolCall(McpToolCallEvent $event): void
    {
        $this->logger->info('mcp.tool.call', [
            'tool'   => $event->getToolName(),
            'user'   => $this->security->getUser()?->getUserIdentifier(),
            'time'   => date('c'),
            'input'  => $event->getInput(),
        ]);
    }
}
```

(Event names and class names follow the upstream `api-platform/mcp` API — adapt to the pinned version.)

---

## 11. Related skills

- `gerard:api-platform-resources` — base resource declaration.
- `gerard:api-platform-state-providers` / `gerard:api-platform-state-processors` — Provider/Processor pattern reused inside MCP tools.
- `gerard:rate-limiting` — dedicated `/mcp` limiter.
- `gerard:api-platform-security` — authentication on the `/mcp` route.
- `gerard:api-platform-errors` — error semantics for tool calls.
