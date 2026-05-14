# Symfony Voters (reference)

## 1. Voter skeleton

```php
namespace App\Security\Voter;

use App\Entity\Post;
use App\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

final class PostVoter extends Voter
{
    public const VIEW   = 'POST_VIEW';
    public const EDIT   = 'POST_EDIT';
    public const DELETE = 'POST_DELETE';
    public const CREATE = 'POST_CREATE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        if (!in_array($attribute, [self::VIEW, self::EDIT, self::DELETE, self::CREATE], true)) {
            return false;
        }
        if (self::CREATE === $attribute) {
            return $subject === null || $subject instanceof Post;
        }
        return $subject instanceof Post;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        if (!$user instanceof User) {
            return false;   // anonymous — denied
        }

        return match ($attribute) {
            self::VIEW   => $this->canView($subject, $user),
            self::EDIT   => $this->canEdit($subject, $user),
            self::DELETE => $this->canDelete($subject, $user),
            self::CREATE => $this->canCreate($user),
            default       => false,
        };
    }

    private function canView(Post $post, User $user): bool
    {
        return $post->isPublished() || $post->getAuthor() === $user || in_array('ROLE_ADMIN', $user->getRoles(), true);
    }

    private function canEdit(Post $post, User $user): bool
    {
        return $post->getAuthor() === $user || in_array('ROLE_ADMIN', $user->getRoles(), true);
    }

    private function canDelete(Post $post, User $user): bool
    {
        return in_array('ROLE_ADMIN', $user->getRoles(), true);
    }

    private function canCreate(User $user): bool
    {
        return in_array('ROLE_USER', $user->getRoles(), true);
    }
}
```

Auto-tagged via `autoconfigure`. No service entry needed.

---

## 2. Wiring — API Platform operation

```php
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\Put;
use ApiPlatform\Metadata\Delete;

new Get(security:    "is_granted('POST_VIEW', object)"),
new Put(security:    "is_granted('POST_EDIT', object)"),
new Delete(security: "is_granted('POST_DELETE', object)"),
```

Cf. `gerard:api-platform-security` for the broader operation-level patterns.

---

## 3. Wiring — controller `#[IsGranted]`

```php
use Symfony\Component\HttpKernel\Attribute\AsController;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[AsController]
final class PostEditController
{
    #[IsGranted('POST_EDIT', subject: 'post')]
    public function __invoke(Post $post): Response
    {
        // ...
    }
}
```

---

## 4. Wiring — programmatic check

```php
use Symfony\Bundle\SecurityBundle\Security;

final readonly class CommentService
{
    public function __construct(private Security $security) {}

    public function reply(Comment $comment, string $body): void
    {
        if (!$this->security->isGranted('COMMENT_REPLY', $comment)) {
            throw new AccessDeniedException();
        }
        // ...
    }
}
```

---

## 5. Wiring — Twig template

```twig
{% if is_granted('POST_EDIT', post) %}
    <a href="{{ path('post_edit', { id: post.id }) }}">Edit</a>
{% endif %}
```

---

## 6. Naming conventions

- Attribute: `<RESOURCE>_<ACTION>` in SCREAMING_SNAKE_CASE.
  - `POST_VIEW`, `POST_EDIT`, `POST_DELETE`, `POST_CREATE`, `POST_PUBLISH`.
- Public constants on the Voter class (`PostVoter::VIEW`) — refer to them everywhere instead of string literals.
- One Voter per resource type. Composite voters (one for multiple resources) become unreadable quickly.

---

## 7. Isolated PHPUnit test pattern

```php
namespace App\Tests\Security\Voter;

use App\Entity\Post;
use App\Entity\User;
use App\Security\Voter\PostVoter;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

final class PostVoterTest extends TestCase
{
    private PostVoter $voter;

    protected function setUp(): void
    {
        $this->voter = new PostVoter();
    }

    public function test_owner_can_edit_their_own_post(): void
    {
        $author = (new User())->setEmail('[email protected]');
        $post   = (new Post())->setAuthor($author)->setPublished(false);
        $token  = $this->createToken($author);

        $this->assertSame(Voter::ACCESS_GRANTED, $this->voter->vote($token, $post, [PostVoter::EDIT]));
    }

    public function test_other_user_cannot_edit_someone_elses_post(): void
    {
        $author = (new User())->setEmail('[email protected]');
        $other  = (new User())->setEmail('[email protected]');
        $post   = (new Post())->setAuthor($author);
        $token  = $this->createToken($other);

        $this->assertSame(Voter::ACCESS_DENIED, $this->voter->vote($token, $post, [PostVoter::EDIT]));
    }

    public function test_admin_can_edit_any_post(): void
    {
        $admin  = (new User())->setEmail('[email protected]')->setRoles(['ROLE_ADMIN']);
        $author = (new User())->setEmail('[email protected]');
        $post   = (new Post())->setAuthor($author);
        $token  = $this->createToken($admin);

        $this->assertSame(Voter::ACCESS_GRANTED, $this->voter->vote($token, $post, [PostVoter::EDIT]));
    }

    public function test_anonymous_cannot_view_unpublished_post(): void
    {
        $post  = (new Post())->setPublished(false);
        $token = $this->createMock(TokenInterface::class);
        $token->method('getUser')->willReturn(null);

        $this->assertSame(Voter::ACCESS_DENIED, $this->voter->vote($token, $post, [PostVoter::VIEW]));
    }

    private function createToken(User $user): TokenInterface
    {
        $token = $this->createMock(TokenInterface::class);
        $token->method('getUser')->willReturn($user);
        return $token;
    }
}
```

Run with `./vendor/bin/phpunit --filter=Voter`.

---

## 8. Voter strategies (multi-voter scenarios)

Symfony's `access_decision_manager` strategy controls how multiple voters combine:

```yaml
security:
    access_decision_manager:
        strategy: affirmative   # any voter granting → granted (default)
        # strategy: unanimous  # every voter must grant or abstain
        # strategy: consensus  # majority grants
        # strategy: priority   # highest-priority voter wins
```

`affirmative` is the default and usually correct. `unanimous` is appropriate when the policy is "must pass every check independently" — defensive.

---

## 9. Best practices

- **Constants over string literals.** Prevents typos and renames.
- **One voter per resource type.** Composite voters fragment the matrix.
- **Test every cell** of the attribute × actor × subject state matrix.
- **No mutations** in voters. They are pure decision functions.
- **No leakage in error responses.** Use a generic `Access denied` — do not reveal which check failed (enumeration risk).
- **Voter-driven `security:`** in API Platform operations once the rule exceeds one boolean clause.
- **Audit log** on sensitive denials (e.g. `POST_DELETE`) — even a denied attempt is interesting forensically.

---

## 10. Related skills

- `gerard:api-platform-security` — Voters wired through `security:` and property-level security.
- `gerard:api-platform-user` — User entity that backs `getUser()`.
- `gerard:tdd-with-phpunit` — TDD for voter logic.
- `gerard:functional-tests` — end-to-end assertions on 401 / 403.
- `gerard:cqrs-and-handlers` — applying voters from command handlers as well as controllers.
