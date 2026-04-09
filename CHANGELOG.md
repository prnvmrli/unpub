# Changelog

All notable changes to this repository are documented in this file.

## 2026-04-09

### Added
- Added PostgreSQL-backed metadata and token store implementations in `unpub`.
- Added workspace-level Docker Compose at repo root for local PostgreSQL test infrastructure.
- Added parallel-safe test database isolation per test file.
- Added secure auth and token-management capabilities across backend and frontend:
  - bcrypt-backed user auth with session cookies
  - permissioned API tokens with hashed storage
  - admin user management and download log views
  - typed dashboard/login routing via `go_router_builder` in `unpub_web`

### Changed
- Migrated `unpub` database layer from MongoDB/SQLite to PostgreSQL.
- Updated CLI defaults and token admin tools to use PostgreSQL URIs.
- Updated package docs/examples (`unpub`, `unpub_aws`) to PostgreSQL usage.
- Refocused `unpub_aws/docker-compose.yml` to AWS-specific local infra (`mock_s3`) only.
- Modernized integration tests to use direct HTTP upload/uploader flows instead of deprecated `dart pub` command behaviors.
- Fixed PostgreSQL token-store trigger bootstrap query sequencing during startup.
- Removed bearer-token login in `unpub_web` and aligned dashboard auth to session-cookie flow only.

## 2026-04-03

### Added
- Added an end-to-end HTTP integration test for package upload and version fetch (`unpub/test/upload_get_http_test.dart`).
- Added workspace root configuration with Melos in root `pubspec.yaml`.
- Added local FVM pin via `.fvmrc` (Flutter `3.41.6`, Dart `3.11.4`).

### Changed
- Migrated the web frontend from AngularDart to Flutter web (`unpub_web` package).
- Updated backend/web integration to serve the Flutter web build path.
- Standardized all package SDK constraints to `^3.11.4`.
- Adopted Dart workspace resolution (`resolution: workspace`) across packages.
- Upgraded direct dependencies to latest resolvable versions within compatibility constraints (including `http 1.x`, `archive 4.x`, and related tooling/lints updates).
- Updated Melos scripts for reliable `dart run melos ...` execution in FVM-based environments.
