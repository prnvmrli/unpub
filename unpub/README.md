# Unpub

[![pub](https://img.shields.io/pub/v/unpub.svg)](https://pub.dev/packages/unpub)

Unpub is a self-hosted private Dart Pub server for Enterprise, with a simple web interface to search and view packages information.

## Screenshots

![Screenshot](https://raw.githubusercontent.com/bytedance/unpub/master/assets/screenshot.png)

## Usage

### Command Line

```sh
pub global activate unpub
unpub --database postgresql://localhost:5432/dart_pub?sslmode=disable # Replace this with production database uri
```

To serve a Flutter web frontend built from `unpub_web`:

```sh
flutter build web --project-dir unpub_web
unpub --database postgresql://localhost:5432/dart_pub?sslmode=disable --web-root unpub_web/build/web
```

To require API key auth (from PostgreSQL) for package and metadata endpoints:

```sh
unpub --database postgresql://localhost:5432/dart_pub?sslmode=disable \
  --token-database postgresql://localhost:5432/dart_pub?sslmode=disable \
  --admin-emails admin@company.com,platform@company.com
```

Clients must send the token via `Authorization: Bearer <token>` (for example via `dart pub token add` / `pub-tokens.json`).
Protected endpoints include:
- `/packages/<name>/versions/<version>.tar.gz`
- `/api/packages/<name>`
- `/api/packages/<name>/versions/<version>`
- `/packages/<name>.json`

The token database uses these tables:

```sql
CREATE TABLE api_keys (
  id BIGSERIAL PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  owner_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active / revoked
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ
);

CREATE TABLE downloads (
  id BIGSERIAL PRIMARY KEY,
  token TEXT NOT NULL,
  package_name TEXT NOT NULL,
  version TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address TEXT
);
```

Example token insert:

```sql
INSERT INTO api_keys (token, owner_name, status, expires_at)
VALUES ('my-secret-token', 'ci-bot', 'active', '2027-01-01T00:00:00Z');
```

`downloads` rows are written on authorized download requests.

Admin scripts:

```sh
# create active token (auto-generated token value)
fvm dart run unpub/tool/create_token.dart \
  --database postgresql://localhost:5432/dart_pub?sslmode=disable \
  --owner ci-bot \
  --expires-at 2027-01-01T00:00:00Z

# revoke token
fvm dart run unpub/tool/revoke_token.dart \
  --database postgresql://localhost:5432/dart_pub?sslmode=disable \
  --token your-token-value
```

Web dashboard session auth:

- `POST /auth/login`
  - Body: `{"token":"<api-token>"}`
  - Sets an `HttpOnly` session cookie (`unpub_session`).
- `GET /auth/me`
  - Returns current session identity.
- `POST /auth/logout`
  - Clears current session cookie.

Admin API (accepts either session cookie or Authorization bearer token):

- `POST /admin/tokens`
  - Body: `{"owner_name":"user@company.com","expires_at":"2027-01-01T00:00:00Z"}`
  - Non-admin users can only create tokens for themselves.
- `GET /admin/tokens/me`
  - Returns caller-owned tokens.
  - Admins can pass `?all=1` to list all.
- `POST /admin/tokens/<id>/revoke`
  - Non-admin users can revoke only their own tokens.

Unpub uses PostgreSQL as the meta/token store and file system as package (tarball) store by default.

Dart API is also available for further customization.

### Dart API

```dart
import 'package:unpub/unpub.dart' as unpub;

main(List<String> args) async {
  final db = await unpub.openPostgreSqlConnection(
    'postgresql://localhost:5432/dart_pub?sslmode=disable',
  );

  final app = unpub.App(
    metaStore: unpub.PostgreSqlMetaStore(db),
    packageStore: unpub.FileStore('./unpub-packages'),
  );

  final server = await app.serve('0.0.0.0', 4000);
  print('Serving at http://${server.address.host}:${server.port}');
}
```

### Options

| Option | Description | Default |
| --- | --- | --- |
| `metaStore` (Required) | Meta information store | - |
| `packageStore` (Required) | Package(tarball) store | - |
| `upstream` | Upstream url | https://pub.dev |
| `googleapisProxy` | Http(s) proxy to call googleapis (to get uploader email) | - |
| `uploadValidator` | See [Package validator](#package-validator) | - |
| `webRoot` | Local directory of built Flutter web assets | - |


### Usage behind reverse-proxy

Using unpub behind reverse proxy(nginx or another), ensure you have necessary headers
```sh
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Server $host;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# Workaround for: 
# Asynchronous error HttpException: 
# Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers
proxy_http_version 1.1;
```

### Package validator

Naming conflicts is a common issue for private registry. A reasonable solution is to add prefix to reduce conflict probability.

With `uploadValidator` you could check if uploaded package is valid.

```dart
var app = unpub.App(
  // ...
  uploadValidator: (Map<String, dynamic> pubspec, String uploaderEmail) {
    // Only allow packages with some specified prefixes to be uploaded
    var prefix = 'my_awesome_prefix_';
    var name = pubspec['name'] as String;
    if (!name.startsWith(prefix)) {
      throw 'Package name should starts with $prefix';
    }

    // Also, you can check if uploader email is valid
    if (!uploaderEmail.endsWith('@your-company.com')) {
      throw 'Uploader email invalid';
    }
  }
);
```

### Customize meta and package store

Unpub is designed to be extensible. It is quite easy to customize your own meta store and package store.

```dart
import 'package:unpub/unpub.dart' as unpub;

class MyAwesomeMetaStore extends unpub.MetaStore {
  // Implement methods of MetaStore abstract class
  // ...
}

class MyAwesomePackageStore extends unpub.PackageStore {
  // Implement methods of PackageStore abstract class
  // ...
}

// Then use it
var app = unpub.App(
  metaStore: MyAwesomeMetaStore(),
  packageStore: MyAwesomePackageStore(),
);
```

#### Available Package Stores

1. [unpub_aws](https://github.com/bytedance/unpub/tree/master/unpub_aws): AWS S3 package store, maintained by [@CleanCode](https://github.com/Clean-Cole).

## Badges

| URL | Badge |
| --- | --- |
| `/badge/v/{package_name}` | ![badge example](https://img.shields.io/static/v1?label=unpub&message=0.1.0&color=orange) ![badge example](https://img.shields.io/static/v1?label=unpub&message=1.0.0&color=blue) |
| `/badge/d/{package_name}` | ![badge example](https://img.shields.io/static/v1?label=downloads&message=123&color=blue) |

## Alternatives

- [pub-dev](https://github.com/dart-lang/pub-dev): Source code of [pub.dev](https://pub.dev), which should be deployed at Google Cloud Platform.
- [pub_server](https://github.com/dart-lang/pub_server): An alpha version of pub server provided by Dart team.

## Credits

- [pub-dev](https://github.com/dart-lang/pub-dev): Web page styles are mostly imported from https://pub.dev directly.
- [shields](https://shields.io): Badges generation.

## License

MIT
