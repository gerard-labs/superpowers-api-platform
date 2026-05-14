# API Platform 4.3 — File upload (reference)

>
> Source: <https://api-platform.com/docs/symfony/file-upload/>.

## 1. Prerequisites

```bash
composer require vich/uploader-bundle

# Optional: Flysystem for S3 / R2 / Cloud storage
composer require vich/flysystem-bundle league/flysystem-bundle league/flysystem-aws-s3-v3
```

---

## 2. Global configuration

```yaml
# config/packages/vich_uploader.yaml
vich_uploader:
    db_driver: orm
    metadata:
        type: attribute
    mappings:
        media_object:
            uri_prefix:         /media
            upload_destination: '%kernel.project_dir%/public/media'
            namer:              Vich\UploaderBundle\Naming\SmartUniqueNamer
```

```yaml
# config/packages/api_platform.yaml — declare the multipart format
api_platform:
    formats:
        jsonld:    ['application/ld+json']
        multipart: ['multipart/form-data']
```

---

## 3. The `MediaObject` resource

```php
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\OpenApi\Model;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\HttpFoundation\File\File;
use Symfony\Component\Serializer\Attribute\Groups;
use Symfony\Component\Validator\Constraints as Assert;
use Vich\UploaderBundle\Mapping\Annotation as Vich;

#[Vich\Uploadable]
#[ORM\Entity]
#[ApiResource(
    normalizationContext: ['groups' => ['media_object:read']],
    types:                ['https://schema.org/MediaObject'],
    outputFormats:        ['jsonld' => ['application/ld+json']],
    operations: [
        new Get(),
        new GetCollection(),
        new Post(
            security:     "is_granted('ROLE_USER')",
            inputFormats: ['multipart' => ['multipart/form-data']],
            openapi: new Model\Operation(
                requestBody: new Model\RequestBody(
                    content: new \ArrayObject([
                        'multipart/form-data' => [
                            'schema' => [
                                'type'       => 'object',
                                'properties' => [
                                    'file' => ['type' => 'string', 'format' => 'binary'],
                                ],
                            ],
                        ],
                    ]),
                ),
            ),
        ),
    ],
)]
class MediaObject
{
    #[ORM\Id, ORM\Column, ORM\GeneratedValue]
    private ?int $id = null;

    #[ApiProperty(types: ['https://schema.org/contentUrl'], writable: false)]
    #[Groups(['media_object:read'])]
    public ?string $contentUrl = null;       // public URL — computed by the normalizer

    #[Vich\UploadableField(mapping: 'media_object', fileNameProperty: 'filePath')]
    #[Assert\NotNull]
    #[Assert\File(maxSize: '5M', mimeTypes: ['image/jpeg', 'image/png', 'image/webp'])]
    public ?File $file = null;               // upload field — multipart

    #[ApiProperty(writable: false)]
    #[ORM\Column(nullable: true)]
    public ?string $filePath = null;
}
```

---

## 4. `MediaObjectNormalizer` — computed `contentUrl`

```php
use ApiPlatform\Metadata\IriConverterInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\Serializer\Normalizer\NormalizerInterface;
use Vich\UploaderBundle\Storage\StorageInterface;

final readonly class MediaObjectNormalizer implements NormalizerInterface
{
    private const ALREADY_CALLED = 'MEDIA_OBJECT_NORMALIZER_ALREADY_CALLED';

    public function __construct(
        #[Autowire(service: 'api_platform.jsonld.normalizer.item')]
        private NormalizerInterface $normalizer,
        private StorageInterface $storage,
    ) {}

    public function normalize(
        $data,
        ?string $format = null,
        array $context = [],
    ): array|string|int|float|bool|\ArrayObject|null {
        $context[self::ALREADY_CALLED] = true;
        $data->contentUrl = $this->storage->resolveUri($data, 'file');
        return $this->normalizer->normalize($data, $format, $context);
    }

    public function supportsNormalization($data, ?string $format = null, array $context = []): bool
    {
        return !isset($context[self::ALREADY_CALLED]) && $data instanceof MediaObject;
    }

    public function getSupportedTypes(?string $format): array
    {
        return [MediaObject::class => false];
    }
}
```

The `ALREADY_CALLED` pattern prevents recursion (cf. `gerard:api-platform-serialization` §7).

---

## 5. Optional multipart `DecoderInterface`

API Platform 4.x ships a default multipart decoder. For special cases (JSON nested inside a multipart part), implement a custom decoder:

```php
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\Serializer\Encoder\DecoderInterface;

final class MultipartDecoder implements DecoderInterface
{
    public const FORMAT = 'multipart';

    public function __construct(private readonly RequestStack $requestStack) {}

    public function decode(string $data, string $format, array $context = []): ?array
    {
        $request = $this->requestStack->getCurrentRequest();
        if (!$request) return null;

        return array_map(
            static fn (string $element) => json_decode($element, true, flags: JSON_THROW_ON_ERROR),
            $request->request->all(),
        ) + $request->files->all();
    }

    public function supportsDecoding(string $format): bool
    {
        return self::FORMAT === $format;
    }
}
```

---

## 6. Linking a MediaObject to another resource

```php
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ApiResource]
class Book
{
    #[ORM\ManyToOne(targetEntity: MediaObject::class)]
    #[ORM\JoinColumn(nullable: true)]
    #[ApiProperty(types: ['https://schema.org/image'])]
    public ?MediaObject $image = null;
}
```

### Client payload

```json
POST /api/books
Content-Type: application/ld+json
{
  "name":  "Le Livre",
  "image": "/api/media_objects/42"
}
```

The image is uploaded separately (multipart POST on `/api/media_objects`), then referenced by IRI on the book (consistent with the IRI-only rule of `gerard:api-platform-resources`).

---

## 7. Constraints and rules

- **HTTP method**: uploads only via **POST** — PUT and PATCH are **not** supported by API Platform for multipart.
- **Validation**: `#[Assert\File(maxSize: '5M', mimeTypes: [...])]` on `$file`.
- **Public path**: the Vich `uri_prefix` must point to a served location (`/public/media/`) or to a CDN.
- **Security**: apply `security: "is_granted('ROLE_USER')"` on the operation — anonymous uploads are rarely intended.
- **S3 / R2 storage**: replace the Vich filesystem storage with `vich/flysystem-bundle` for cloud object storage.
- **Antivirus**: for sensitive apps, wire a ClamAV scan via a Processor decorator (before persistence).
- **CDN / Cache**: `contentUrl` must be an absolute, stable, cacheable URL.

---

## 8. S3 / R2 storage with Vich-Flysystem

```yaml
flysystem:
    storages:
        media.storage:
            adapter: 'aws'
            options:
                client: 'aws_s3_client'
                bucket: '%env(S3_BUCKET)%'

vich_uploader:
    db_driver: orm
    storage:   flysystem
    mappings:
        media_object:
            uri_prefix:         '%env(CDN_URL)%/media'
            upload_destination: 'media.storage'
            namer:              Vich\UploaderBundle\Naming\SmartUniqueNamer
```

The `MediaObjectNormalizer` keeps working unchanged — `StorageInterface::resolveUri()` produces a URL pointing to the CDN.

---

## 9. Antivirus integration (ClamAV)

```php
final readonly class ClamAvProcessor implements ProcessorInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private ProcessorInterface $persist,
        private ClamAvClient $clamAv,
    ) {}

    public function process(mixed $data, Operation $op, array $uriVars = [], array $ctx = []): mixed
    {
        if ($data instanceof MediaObject && $data->file) {
            if (!$this->clamAv->scan($data->file->getPathname())) {
                throw new MaliciousFileException('File rejected by antivirus.');
            }
        }
        return $this->persist->process($data, $op, $uriVars, $ctx);
    }
}
```

Wire as `processor:` on the `Post` operation; pair with `#[ErrorResource]` for a clean error contract (cf. `gerard:api-platform-errors`).

---

## 10. Test pattern

```php
use Symfony\Component\HttpFoundation\File\UploadedFile;

public function test_can_upload_a_media_object(): void
{
    $file = new UploadedFile(__DIR__.'/../fixtures/image.jpg', 'image.jpg');

    $client = static::createClient();
    $client->request('POST', '/api/media_objects', [
        'headers' => ['Content-Type' => 'multipart/form-data'],
        'extra'   => ['files' => ['file' => $file]],
    ]);

    $this->assertResponseIsSuccessful();
    $this->assertMatchesResourceItemJsonSchema(MediaObject::class);
}

public function test_invalid_mime_type_returns_422(): void
{
    $file = new UploadedFile(__DIR__.'/../fixtures/malware.exe', 'malware.exe');

    static::createClient()->request('POST', '/api/media_objects', [
        'headers' => ['Content-Type' => 'multipart/form-data'],
        'extra'   => ['files' => ['file' => $file]],
    ]);

    $this->assertResponseStatusCodeSame(422);
}
```

---

## 11. Related skills

- `gerard:api-platform-resources` — multipart on `Post` only, IRI-only relations.
- `gerard:api-platform-serialization` — Normalizer `ALREADY_CALLED` pattern.
- `gerard:api-platform-security` — `is_granted('ROLE_USER')` on upload, quota voters.
- `gerard:api-platform-state-processors` — Processor decoration for antivirus, additional side effects.
- `gerard:api-platform-tests` — multipart upload test recipe.
- `gerard:api-platform-errors` — modeling `MaliciousFileException` as an `#[ErrorResource]`.
