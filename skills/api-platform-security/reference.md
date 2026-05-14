# API Platform 4.3 — Security (reference)

## 1. Operation-level security

- **`security: "is_granted('ROLE_USER')"`** on `Post`, `Put`, `Patch`, `Delete`.
- **`securityMessage`**: explicit refusal message — UX and debugging.
- **`securityPostDenormalize`**: check after the input is denormalized. `previous_object` is available — useful to enforce invariants like "the author cannot change".
- **`securityPostValidation`**: check after validation, useful when you need to validate first.
- **`securityPostDenormalizeMessage`**: dedicated message for the post-denormalize check.
- **Fail closed by default.** No `security` = readable by anyone, only if it is intentional.
- **4.3 perf note**: when the expression does **not** reference `object`, it is evaluated **before** the state provider — saves a DB roundtrip on refused requests.

```php
new Put(
    security: "is_granted('ROLE_ADMIN') or object.getAuthor() == user",
    securityMessage: 'You can only edit your own posts.',
    // previous_object guarantees the author did not change in the payload
    securityPostDenormalize: "is_granted('ROLE_ADMIN') or (object.getAuthor() == user and previous_object.getAuthor() == user)",
    securityPostDenormalizeMessage: 'Cannot transfer ownership.',
    extraProperties: ['throw_on_access_denied' => true],   // explicit 403 (vs silent filter)
),
new Post(
    security: "is_granted('ROLE_USER')",
    securityPostDenormalize: "is_granted('POST_CREATE', object)",
    securityPostDenormalizeMessage: 'You cannot create this type of post.',
),
```

### Variables in security expressions

| Variable | Available in | Description |
|---|---|---|
| `user` | all | Current user (or `null` if anonymous) |
| `object` | `security`, `securityPostDenormalize`, `securityPostValidation` | Target resource (`null` in the 4.3 pre-provider evaluation when not referenced) |
| `previous_object` | `securityPostDenormalize` only | State before modification (useful for PUT/PATCH) |
| `request` | all | The Symfony `Request` |

### Why `throw_on_access_denied`

Without this flag, an unauthorized property change is **silently dropped** — the property is denormalized but not written. With it, API Platform throws a 403 — the explicit behavior we want for an audit-friendly contract.

---

## 2. Voters

Once the access logic exceeds a single expression, switch to a **Voter**. The expression becomes `is_granted('POST_EDIT', object)`.

```php
new Get(security:    "is_granted('POST_VIEW', object)"),
new Put(security:    "is_granted('POST_EDIT', object)"),
new Delete(security: "is_granted('POST_DELETE', object)"),
```

Attribute conventions: `POST_VIEW`, `POST_EDIT`, `POST_DELETE`, `POST_CREATE`. Test each voter in isolation with `./vendor/bin/phpunit --filter=Voter`.

Detailed voter patterns: `gerard:symfony-voters`.

---

## 3. Filtering collections by current user

Implement `QueryCollectionExtensionInterface` (and `QueryItemExtensionInterface` for direct-access lookups).

```php
use ApiPlatform\Doctrine\Orm\Extension\QueryCollectionExtensionInterface;
use ApiPlatform\Doctrine\Orm\Extension\QueryItemExtensionInterface;
use ApiPlatform\Doctrine\Orm\Util\QueryNameGeneratorInterface;
use ApiPlatform\Metadata\Operation;
use App\Entity\Post;
use Doctrine\ORM\QueryBuilder;
use Symfony\Bundle\SecurityBundle\Security;

final class CurrentUserExtension implements QueryCollectionExtensionInterface, QueryItemExtensionInterface
{
    public function __construct(private Security $security) {}

    public function applyToCollection(
        QueryBuilder $queryBuilder,
        QueryNameGeneratorInterface $queryNameGenerator,
        string $resourceClass,
        ?Operation $operation = null,
        array $context = [],
    ): void {
        if ($resourceClass !== Post::class) {
            return;
        }
        $this->addWhere($queryBuilder);
    }

    public function applyToItem(
        QueryBuilder $queryBuilder,
        QueryNameGeneratorInterface $queryNameGenerator,
        string $resourceClass,
        array $identifiers,
        ?Operation $operation = null,
        array $context = [],
    ): void {
        if ($resourceClass !== Post::class) {
            return;
        }
        $this->addWhere($queryBuilder);
    }

    private function addWhere(QueryBuilder $qb): void
    {
        // Short-circuit for admins
        if ($this->security->isGranted('ROLE_ADMIN')) return;

        $user  = $this->security->getUser();
        $alias = $qb->getRootAliases()[0];

        if ($user) {
            $qb->andWhere("$alias.isPublished = true OR $alias.author = :currentUser")
               ->setParameter('currentUser', $user);
        } else {
            $qb->andWhere("$alias.isPublished = true");
        }
    }
}
```

Auto-tagged when autoconfigure is on. The same instance covers both collection and item.

---

## 4. Property-level security

### Option A — group-based

Hide a property by placing it in a group only granted to specific roles, then trigger that group via a Context Builder (cf. `gerard:api-platform-serialization` §15).

### Option B — `#[ApiProperty(security: ...)]`

Inline the condition on the property — defense in depth at the serialization layer.

```php
#[ApiResource]
class Order
{
    #[ApiProperty(security: "is_granted('ROLE_ADMIN')")]
    private float $internalCost;

    #[ApiProperty(security: "is_granted('finance.view')")]
    private float $supplierCost;
}
```

Property-level security is **complementary** to groups, not a replacement. Use it for cross-cutting fields (admin vs user) without the overhead of a Context Builder.

---

## 5. Identifiers — UUID v7 / ULID (anti-enumeration)

Auto-incremented IDs leak information on public resources:

- `/orders/42051` reveals volume.
- An attacker can scan every resource by incrementing.

Use:

- **UUID v7** (`Symfony\Component\Uid\Uuid::v7()`) — globally unique, non-guessable, **chronologically sortable** (timestamp prefix → ideal for cursor pagination, B-tree indexing).
- **ULID** (`Symfony\Component\Uid\Ulid`) — same guarantees, slightly shorter string form.

```php
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use Symfony\Component\Uid\Uuid;

#[ApiResource]
class Order
{
    #[ApiProperty(identifier: true)]
    public Uuid $id;
}
```

Database side: native `uuid` column (PostgreSQL) rather than `varchar(36)` for better indexing.

Detailed identifier strategies: `gerard:api-platform-identifiers`.

---

## 6. JWT authentication (LexikJWTAuthenticationBundle)

> The API Platform documentation suggests OIDC as the preferred standard for new projects (interop with Auth0 / Keycloak / Okta / Azure AD). JWT-custom remains valid for simplicity or legacy.

### Installation

```bash
composer require lexik/jwt-authentication-bundle
php bin/console lexik:jwt:generate-keypair
# Add to .gitignore and .dockerignore : config/jwt/
```

### `config/packages/lexik_jwt_authentication.yaml`

```yaml
lexik_jwt_authentication:
    secret_key:  '%env(resolve:JWT_SECRET_KEY)%'
    public_key:  '%env(resolve:JWT_PUBLIC_KEY)%'
    pass_phrase: '%env(JWT_PASSPHRASE)%'
    api_platform:
        check_path:    /auth
        username_path: email
        password_path: password
```

### `config/packages/security.yaml`

```yaml
security:
    password_hashers:
        App\Entity\User: 'auto'                    # bcrypt/argon2id auto

    providers:
        users:
            entity:
                class:    App\Entity\User
                property: email

    firewalls:
        dev:
            pattern: ^/_(profiler|wdt)
            security: false

        api:
            pattern:   ^/api
            stateless: true
            provider:  users
            jwt:       ~

        main:
            stateless: true
            provider:  users
            json_login:
                check_path:        /auth
                username_path:     email
                password_path:     password
                success_handler:   lexik_jwt_authentication.handler.authentication_success
                failure_handler:   lexik_jwt_authentication.handler.authentication_failure

    access_control:
        - { path: ^/auth,                roles: PUBLIC_ACCESS }
        - { path: ^/api/docs,            roles: PUBLIC_ACCESS }
        - { path: ^/api/contexts,        roles: PUBLIC_ACCESS }
        - { path: ^/api/media_objects,   roles: PUBLIC_ACCESS, methods: [GET] }
        - { path: ^/api,                 roles: IS_AUTHENTICATED_FULLY }
```

### Swagger UI integration

```yaml
# config/packages/api_platform.yaml
api_platform:
    swagger:
        api_keys:
            JWT:
                name: Authorization
                type: header
```

The user enters `Bearer <token>` in the "Authorize" dialog of Swagger UI.

### Authentication endpoint (if not auto-generated)

```yaml
# config/routes.yaml
auth:
    path:    /auth
    methods: [POST]
```

### Token security rules

- **Short-lived access token** — 1 hour max. Limits the window of exploitation if stolen.
- **Refresh token** in parallel, longer lifetime (days/weeks) — `markitosgv/jwt-refresh-token-bundle` or a custom implementation.
- **Client storage**: `HttpOnly` (inaccessible to JS → XSS protection) + `Secure` (HTTPS only) + `SameSite=Strict` (CSRF protection). **Never `localStorage`.**
- **Revocation**:
  - Simple: short-lived (expiration suffices).
  - Strict: `jti` claim + Redis blacklist.
- **Forced re-auth**: tag the user when their critical permissions change, force a re-login.
- **JWT contents**: `sub` (user UUID / ULID), `roles`, `iss`, `exp`, `iat`, `jti`. **No PII** in claims (the JWT is readable).
- **Keys**: RS256 (RSA) for multi-service deployments; HS256 (HMAC) acceptable in a monolith.

### Lightweight password hashing in tests

```yaml
# config/packages/test/security.yaml
security:
    password_hashers:
        App\Entity\User:
            algorithm:        md5
            encode_as_base64: false
            iterations:       0
```

Speeds up the test suite ×5 once you have user creations. Detailed user entity patterns: `gerard:api-platform-user`.

---

## 7. OIDC alternative (recommended)

- Bundle options: `web-token/jwt-bundle`, `pdtdev/oidc-bundle` (Keycloak, Auth0, Okta).
- Discovery via `.well-known/openid-configuration` — no manual key management.
- Standardized refresh token, scopes, claims.

The user provider stays the same; only the authenticator changes.

---

## 8. CORS

Without proper CORS, an authenticated session (cookie-based) can be abused from a malicious origin (CSRF / exfiltration). API Platform supports CORS natively through `nelmio/cors-bundle`.

```yaml
nelmio_cors:
    defaults:
        allow_credentials: true
        allow_origin: ['%env(CORS_ALLOW_ORIGIN)%']
        allow_headers: ['Content-Type', 'Authorization']
        allow_methods: ['GET','POST','PUT','PATCH','DELETE']
        expose_headers: ['Link']
        max_age: 3600
    paths:
        '^/api/': ~
```

Rules:

- **Explicit origins** — never `*` when `allow_credentials: true`. List trusted domains (official UI, partner portals).
- **Limit methods** to those actually used.
- **Expose headers explicitly** — avoid leaking internal metadata.
- **`max_age`** to cache preflight responses (perf).

---

## 9. Cross-cutting rules

1. **Voters for complex authorizations.** Expressions for one-liners.
2. **Doctrine extensions for collection filtering.** Centralize the rule, don't repeat it per operation.
3. **Fail secure** — deny by default.
4. **Clear messages** with `securityMessage`.
5. **Test both refusal and acceptance.**
6. **Audit sensitive operations** (structured log line per write).

---

## 10. Validation commands

```bash
php bin/console debug:container security
./vendor/bin/phpunit --filter=Voter
./vendor/bin/phpunit --filter=Security

# JWT tooling
php bin/console lexik:jwt:generate-keypair
```

---

## 11. Related skills

- `gerard:symfony-voters` — voter design and isolated tests.
- `gerard:rate-limiting` — extra layer for sensitive endpoints (login throttling, write quotas).
- `gerard:api-platform-identifiers` — UUID v7 / ULID strategies.
- `gerard:api-platform-user` — User entity, password hashing, `/me` endpoint.
- `gerard:api-platform-serialization` — Context Builder for dynamic groups.
- `gerard:api-platform-errors` — 401 / 403 / 422 shapes (RFC 7807).
