# API Platform 4.3 — User entity (reference)

>
> Source: <https://api-platform.com/docs/symfony/user/>.

## 1. The entity

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\Put;
use App\State\UserPasswordHasher;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Serializer\Attribute\Groups;
use Symfony\Component\Validator\Constraints as Assert;

#[ApiResource(
    operations: [
        new GetCollection(security: "is_granted('ROLE_ADMIN')"),
        new Post(
            processor:         UserPasswordHasher::class,
            validationContext: ['groups' => ['Default', 'user:create']],
            // public — registration is open
        ),
        new Get(security:    "is_granted('ROLE_USER')"),
        new Put(processor:   UserPasswordHasher::class, security: "object == user or is_granted('ROLE_ADMIN')"),
        new Patch(processor: UserPasswordHasher::class, security: "object == user or is_granted('ROLE_ADMIN')"),
        new Delete(security: "is_granted('ROLE_ADMIN')"),
    ],
    normalizationContext:   ['groups' => ['user:read']],
    denormalizationContext: ['groups' => ['user:create', 'user:update']],
)]
#[ORM\Entity(repositoryClass: UserRepository::class)]
#[ORM\Table(name: '`user`')]              // reserved word — quoted table
#[UniqueEntity('email')]
class User implements UserInterface, PasswordAuthenticatedUserInterface
{
    #[Groups(['user:read'])]
    #[ORM\Id, ORM\Column, ORM\GeneratedValue]
    private ?int $id = null;

    #[Assert\NotBlank, Assert\Email]
    #[Groups(['user:read', 'user:create', 'user:update'])]
    #[ORM\Column(length: 180, unique: true)]
    private ?string $email = null;

    #[ORM\Column]
    private ?string $password = null;        // hashed — NEVER in a Group

    #[Assert\NotBlank(groups: ['user:create'])]
    #[Groups(['user:create', 'user:update'])]
    private ?string $plainPassword = null;   // transient — not persisted

    #[ORM\Column(type: 'json')]
    private array $roles = [];

    public function getUserIdentifier(): string { return (string) $this->email; }
    public function getRoles(): array { return array_unique([...$this->roles, 'ROLE_USER']); }
    public function eraseCredentials(): void { /* no-op (plainPassword is wiped by the processor) */ }

    public function getPassword(): ?string { return $this->password; }
    public function setPassword(string $password): void { $this->password = $password; }
    public function getPlainPassword(): ?string { return $this->plainPassword; }
    public function setPlainPassword(?string $plain): void { $this->plainPassword = $plain; }

    // getEmail, setEmail, getId, ...
}
```

### Key rules

- `UserInterface` + `PasswordAuthenticatedUserInterface` (required by Symfony Security).
- `password` field **never** in any `#[Groups]` — it never appears in a response.
- `plainPassword` field **not persisted** (no `#[ORM\Column]`), validated only at creation (`user:create` group).
- `getUserIdentifier()` returns the email (or a ULID/UUID — anything stable).
- `getRoles()` injects `ROLE_USER` by default + deduplicates.
- `#[UniqueEntity('email')]` prevents duplicates in addition to the `unique: true` SQL constraint.
- `Default` + `user:create` in the POST `validationContext` — `Default` covers ungrouped constraints, `user:create` adds the registration-specific ones.

---

## 2. The State Processor

```php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use App\Entity\User;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/** @implements ProcessorInterface<User, User> */
final readonly class UserPasswordHasher implements ProcessorInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private ProcessorInterface $processor,
        private UserPasswordHasherInterface $passwordHasher,
    ) {}

    public function process(mixed $data, Operation $op, array $uriVars = [], array $ctx = []): User
    {
        if ($data->getPlainPassword()) {
            $data->setPassword($this->passwordHasher->hashPassword($data, $data->getPlainPassword()));
            $data->setPlainPassword(null);   // wipe from memory — no leakage in logs
        }
        return $this->processor->process($data, $op, $uriVars, $ctx);
    }
}
```

`#[Autowire(service: ...)]` decorates the Doctrine persist processor — equivalent to the older `services.yaml` `bind` pattern, but more local and explicit.

---

## 3. Repository — `PasswordUpgraderInterface`

```php
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\PasswordUpgraderInterface;
use Symfony\Component\Security\Core\Exception\UnsupportedUserException;

class UserRepository extends ServiceEntityRepository implements PasswordUpgraderInterface
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }

    public function upgradePassword(PasswordAuthenticatedUserInterface $user, string $newHashedPassword): void
    {
        if (!$user instanceof User) {
            throw new UnsupportedUserException(sprintf('Instances of "%s" are not supported.', get_class($user)));
        }
        $user->setPassword($newHashedPassword);
        $this->getEntityManager()->flush();
    }
}
```

Symfony automatically rehashes the password when the target algorithm (`auto` in `password_hashers`) evolves — no application-code change required.

---

## 4. `/me` endpoint — current user

```php
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use App\State\CurrentUserProvider;

#[ApiResource]
#[Get(
    uriTemplate: '/me',
    provider:    CurrentUserProvider::class,
    security:    "is_granted('ROLE_USER')",
    name:        'get_current_user',
)]
class User { /* ... */ }
```

```php
// src/State/CurrentUserProvider.php
use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use Symfony\Bundle\SecurityBundle\Security;

final readonly class CurrentUserProvider implements ProviderInterface
{
    public function __construct(private Security $security) {}

    public function provide(Operation $op, array $uriVars = [], array $ctx = []): ?User
    {
        return $this->security->getUser();
    }
}
```

Provider-based — works for REST and GraphQL, unlike a custom invokable controller.

---

## 5. Test environment — lightweight hashing

```yaml
# config/packages/test/security.yaml
security:
    password_hashers:
        App\Entity\User:
            algorithm:        md5
            encode_as_base64: false
            iterations:       0
```

Speeds the suite ×5 as soon as you create users. **Never** apply this elsewhere.

---

## 6. Best practices

- **Public registration**: `Post` operation **without `security:`** + strict `validationContext`.
- **Profile update**: `security: "object == user or is_granted('ROLE_ADMIN')"`.
- **Voter delegation** when the access logic gets richer (`is_granted('USER_EDIT', object)`).
- **OAuth/OIDC** (recommended alternative to custom JWT — cf. `gerard:api-platform-security`): the user provider stays the same; only the authenticator changes.
- **Hash-light in tests** only — never in dev / staging / prod.
- **Delegate hashing to Symfony** (`password_hashers: { App\Entity\User: 'auto' }`) so it picks the best available algorithm (bcrypt / argon2id).
- **Audit log** on registration / password change — track the actor, user, timestamp.

---

## 7. Functional test snippets

```php
public function test_registration_is_public(): void
{
    static::createClient()->request('POST', '/api/users', [
        'json' => ['email' => '[email protected]', 'plainPassword' => 's3cr3t'],
    ]);
    $this->assertResponseStatusCodeSame(201);
    $this->assertMatchesResourceItemJsonSchema(User::class);
}

public function test_password_is_never_in_response(): void
{
    $user = UserFactory::createOne();
    $response = static::createClient()->request('GET', '/api/users/' . $user->getId(), [
        'auth_bearer' => $this->getToken($user->object()),
    ]);
    $this->assertArrayNotHasKey('password',      $response->toArray());
    $this->assertArrayNotHasKey('plainPassword', $response->toArray());
}

public function test_me_returns_current_user(): void
{
    $user = UserFactory::createOne(['email' => '[email protected]']);
    $response = static::createClient()->request('GET', '/api/me', [
        'auth_bearer' => $this->getToken($user->object()),
    ]);
    $this->assertResponseIsSuccessful();
    $this->assertJsonContains(['email' => '[email protected]']);
}
```

---

## 8. Related skills

- `gerard:api-platform-security` — JWT/Lexik, OIDC, CORS, voters.
- `gerard:api-platform-state-processors` — Processor decorator pattern.
- `gerard:api-platform-resources` — `/me` via Provider (REST + GraphQL).
- `gerard:api-platform-tests` — `auth_bearer`, hash-light, schema assertions.
- `gerard:symfony-voters` — `USER_VIEW`, `USER_EDIT` voter design.
