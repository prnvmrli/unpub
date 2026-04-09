## 1.1.1

- Remove bearer-token login path from the frontend and enforce email/password session login only.
- Simplify login state/UI to a single session-auth flow.
- Update login cubit tests to match password-only authentication.

## 1.1.0

- Add configurable HTTP API client with cookie-based browser credentials and typed auth/token methods.
- Add email/password login flow while retaining bearer-token login fallback.
- Add dashboard routing and migrate router definitions to `go_router_builder` typed routes.
- Add role-aware admin UI sections (admin/developer/client rendering).
- Add token management UX improvements:
  - token creation with name, expiry days, and permission flags
  - one-time token display dialog with copy support
  - token list table with revoke actions and permission metadata
- Add user management screen (admin-only) with list and disable actions.

## 1.0.0

- Rebuilt the frontend as a Flutter web application.
- Replaced legacy AngularDart UI components with Flutter-based pages for package listing and details.
- Aligned package/tooling constraints with Dart `^3.11.4` and workspace-based dependency resolution.
