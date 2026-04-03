# Changelog

All notable changes to this repository are documented in this file.

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

