## 3.1.1

- Fix PostgreSQL trigger initialization for user-disable token revocation by executing trigger drop/create statements separately.

## 3.1.0

- Add secure token model with `token_prefix + token_hash` storage and SHA-256 verification.
- Add token permissions (`can_download`, `can_publish`), token expiry, and revoke semantics.
- Add PostgreSQL-backed users/tokens/download_logs schema with role support and user-disable token revocation trigger.
- Add session-based auth endpoints with bcrypt email/password login support (`/auth/login`, `/auth/me`, `/auth/logout`).
- Add admin user management APIs (`/admin/users`, `/admin/users/<id>/disable`).
- Add stricter middleware authorization for download/publish flows with proper `403` permission responses.
- Update token CLI tooling to align with new secure token schema.

## 3.0.0

- Replace MongoDB metadata storage with PostgreSQL-backed metadata storage.
- Replace SQLite token storage with PostgreSQL-backed token and download-log storage.
- Add PostgreSQL connection helpers and PostgreSQL store implementations.
- Update CLI and token management tools to PostgreSQL database URIs.
- Migrate tests to PostgreSQL and make test database usage parallel-safe.
- Update documentation and examples to PostgreSQL defaults.

## 2.0.1

- Migrate frontend experience to Flutter web (`unpub_web`) and integrate serving with the unpub backend.
- Add HTTP integration test coverage for upload and metadata fetch flows.
- Upgrade core dependencies for Dart 3.11 compatibility (including `http 1.x`, `archive 4.x`, `googleapis 16.x`, and `mime 2.x`).

## 2.0.0

- Supports NNBD
- Fixes Web styles

## 1.2.1

## 1.2.0

- Supports mongodb pool connection
- Update web page styles

## 1.1.0

- Add badges for version and downloads
- Fix web page styles

## 1.0.0

## 0.4.0

## 0.3.0

## 0.2.2

## 0.2.1

## 0.2.0

- Refactor
- Semver whitelist

## 0.1.1

- Get email via Google APIs
- Upload validator

## 0.1.0

- `pub get`
- `pub publish` with permission check

## 0.0.1

- Initial version, created by Stagehand
