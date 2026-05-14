---
name: api-platform-file-upload
description: Implement file uploads in API Platform 4.3 with the canonical pattern — VichUploaderBundle (`#[Vich\\Uploadable]`, `#[Vich\\UploadableField]`), the `multipart/form-data` format enabled on the `Post` operation (`inputFormats: ['multipart' => …]`), a `MediaObject` resource exposing `contentUrl` via a custom Normalizer that resolves the URL through `Vich\\Storage\\StorageInterface`, the OpenAPI request body annotation (`Model\\RequestBody` with `multipart/form-data` schema and a binary file property), an optional custom multipart `DecoderInterface` for JSON-in-multipart payloads, linking a `MediaObject` to another resource via a regular relation + IRI, Vich-Flysystem for S3/R2 storage, ClamAV antivirus via a Processor decorator, and the test pattern using `Symfony\\Component\\HttpFoundation\\File\\UploadedFile`. Trigger on "upload an image", "MediaObject", "multipart", or "VichUploader".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
effort:
  low: SKILL.md only — "Use when" + default workflow + key bullets.
  high: SKILL.md + reference.md — full doctrine.
  xhigh: SKILL.md + reference.md + project overrides (.claude/skills/*/api-platform-file-upload/) + edge cases.
---

# API Platform 4.3 — File upload

## Use when
- The API needs to accept file uploads (images, documents, exports re-uploaded by users).
- A resource has an image / file relation (e.g. `Book::image`).
- Uploads must be authenticated and validated for size / MIME type.
- Files need to live on S3 / R2 / Cloud storage instead of the local filesystem.

## Default workflow
1. `composer require vich/uploader-bundle` (+ `vich/flysystem-bundle` for cloud storage).
2. Configure Vich mappings (uri_prefix, upload_destination, namer).
3. Enable the `multipart/form-data` format on the `Post` operation only — never on PUT/PATCH (unsupported by API Platform for multipart).
4. Model a `MediaObject` resource with `#[Vich\Uploadable]` + `#[Vich\UploadableField(fileNameProperty: 'filePath')]`.
5. Add a `MediaObjectNormalizer` that resolves `contentUrl` via `Vich\Storage\StorageInterface::resolveUri()`.
6. (Optional) Add a multipart `DecoderInterface` if you need JSON nested in a multipart part.
7. Apply security: `is_granted('ROLE_USER')` minimum; consider antivirus and quota voters.

## Guardrails
- **Uploads only via POST.** PUT/PATCH multipart is not supported by API Platform.
- **Validate file size + MIME** with `#[Assert\File(maxSize: '5M', mimeTypes: ['image/jpeg', 'image/png'])]`.
- **Storage path must be public** (`/public/media/`) or fronted by a CDN.
- **Antivirus** for any app that accepts files from untrusted users — wire ClamAV via a Processor decorator.
- **No raw entity exposure** — always normalize via `contentUrl` rather than the raw `filePath`.

## Progressive disclosure
- `SKILL.md` covers posture and rules.
- `reference.md` carries the full pattern: prerequisites, configuration, the `MediaObject` resource, the `MediaObjectNormalizer` (`ALREADY_CALLED` pattern), optional multipart Decoder, linking to other resources, constraints, S3/R2 storage, antivirus integration, and the test recipe.

## Output contract
- A `MediaObject` resource accepting `multipart/form-data` on POST only.
- A normalizer producing a `contentUrl` field (absolute, cacheable).
- Validation on `file` (size, MIME).
- Security on the upload operation.
- Functional test using `UploadedFile` + schema assertion.

## References
- `reference.md`
