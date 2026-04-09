import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:unpub/unpub.dart' as unpub;
import 'utils.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late PostgreSQLConnection db;
  late unpub.PostgreSqlTokenStore tokenStore;

  setUpAll(() async {
    db = await openTestDb(databaseName: 'dart_pub_test_auth');
    await db.query('DROP TABLE IF EXISTS download_logs');
    await db.query('DROP TABLE IF EXISTS tokens');
    await db.query('DROP TABLE IF EXISTS users');
    tokenStore = unpub.PostgreSqlTokenStore(db);

    final app = unpub.App(
      metaStore: _MemoryMetaStore(),
      packageStore: _MemoryPackageStore(),
      tokenStore: tokenStore,
      adminEmails: {'admin@example.com'},
    );
    server = await app.serve('127.0.0.1', 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
    await db.query('DROP TABLE IF EXISTS download_logs');
    await db.query('DROP TABLE IF EXISTS tokens');
    await db.query('DROP TABLE IF EXISTS users');
    await db.close();
  });

  test('session login/me/logout and admin access over cookie', () async {
    final created = await tokenStore.createToken(
      ownerName: 'admin@example.com',
      name: 'admin-session-token',
    );

    final loginRes = await http.post(
      baseUri.resolve('/auth/login'),
      headers: {'content-type': 'application/json'},
      body: json.encode({'token': created.token}),
    );
    expect(loginRes.statusCode, HttpStatus.ok);
    final setCookie = loginRes.headers['set-cookie'];
    expect(setCookie, isNotNull);
    expect(setCookie, contains('unpub_session='));

    final cookieHeader = setCookie!.split(';').first;

    final meRes = await http.get(
      baseUri.resolve('/auth/me'),
      headers: {'cookie': cookieHeader},
    );
    expect(meRes.statusCode, HttpStatus.ok);
    final meJson = json.decode(meRes.body) as Map<String, dynamic>;
    expect(
      (meJson['data'] as Map<String, dynamic>)['owner_name'],
      'admin@example.com',
    );

    final tokensRes = await http.get(
      baseUri.resolve('/admin/tokens/me?all=1'),
      headers: {'cookie': cookieHeader},
    );
    expect(tokensRes.statusCode, HttpStatus.ok);

    final logoutRes = await http.post(
      baseUri.resolve('/auth/logout'),
      headers: {'cookie': cookieHeader, 'content-type': 'application/json'},
      body: '{}',
    );
    expect(logoutRes.statusCode, HttpStatus.ok);
    expect(logoutRes.headers['set-cookie'], contains('Max-Age=0'));

    final tokensAfterLogout = await http.get(
      baseUri.resolve('/admin/tokens/me'),
      headers: {'cookie': cookieHeader},
    );
    expect(tokensAfterLogout.statusCode, HttpStatus.unauthorized);
  });

  test('admin API still supports bearer token auth', () async {
    final created = await tokenStore.createToken(
      ownerName: 'owner@example.com',
      name: 'owner-bearer-token',
    );
    final tokensRes = await http.get(
      baseUri.resolve('/admin/tokens/me'),
      headers: {'authorization': 'Bearer ${created.token}'},
    );
    expect(tokensRes.statusCode, HttpStatus.ok);
  });

  test('metadata and tarball routes require bearer token', () async {
    final created = await tokenStore.createToken(
      ownerName: 'pkg-user@example.com',
      name: 'pkg-user-token',
    );

    final unauthorizedMeta = await http.get(
      baseUri.resolve('/api/packages/test_pkg'),
    );
    expect(unauthorizedMeta.statusCode, HttpStatus.unauthorized);

    final authorizedMeta = await http.get(
      baseUri.resolve('/api/packages/test_pkg'),
      headers: {'authorization': 'Bearer ${created.token}'},
    );
    expect(authorizedMeta.statusCode, HttpStatus.ok);

    final unauthorizedTar = await http.get(
      baseUri.resolve('/packages/test_pkg/versions/1.0.0.tar.gz'),
    );
    expect(unauthorizedTar.statusCode, HttpStatus.unauthorized);

    final authorizedTar = await http.get(
      baseUri.resolve('/packages/test_pkg/versions/1.0.0.tar.gz'),
      headers: {'authorization': 'Bearer ${created.token}'},
    );
    expect(authorizedTar.statusCode, HttpStatus.ok);
    expect(authorizedTar.bodyBytes, utf8.encode('fake-tarball'));
  });

  test('auth login fails with invalid token', () async {
    final loginRes = await http.post(
      baseUri.resolve('/auth/login'),
      headers: {'content-type': 'application/json'},
      body: json.encode({'token': 'does-not-exist'}),
    );
    expect(loginRes.statusCode, HttpStatus.unauthorized);
  });

  test('session cookie cannot access protected metadata endpoints', () async {
    final created = await tokenStore.createToken(
      ownerName: 'meta-user@example.com',
      name: 'meta-user-token',
    );

    final loginRes = await http.post(
      baseUri.resolve('/auth/login'),
      headers: {'content-type': 'application/json'},
      body: json.encode({'token': created.token}),
    );
    expect(loginRes.statusCode, HttpStatus.ok);
    final cookieHeader = loginRes.headers['set-cookie']!.split(';').first;

    final byCookieOnly = await http.get(
      baseUri.resolve('/api/packages/test_pkg'),
      headers: {'cookie': cookieHeader},
    );
    expect(byCookieOnly.statusCode, HttpStatus.unauthorized);
  });

  test('admin endpoint is unauthorized without session or bearer', () async {
    final res = await http.get(baseUri.resolve('/admin/tokens/me'));
    expect(res.statusCode, HttpStatus.unauthorized);
  });

  test(
    'static download token mode supports auth login and admin bearer',
    () async {
      final staticApp = unpub.App(
        metaStore: _MemoryMetaStore(),
        packageStore: _MemoryPackageStore(),
        downloadToken: 'static-secret',
        adminEmails: {'static-token-user'},
      );
      final staticServer = await staticApp.serve('127.0.0.1', 0);
      final staticBaseUri = Uri.parse('http://127.0.0.1:${staticServer.port}');
      try {
        final loginRes = await http.post(
          staticBaseUri.resolve('/auth/login'),
          headers: {'content-type': 'application/json'},
          body: json.encode({'token': 'static-secret'}),
        );
        expect(loginRes.statusCode, HttpStatus.ok);
        expect(loginRes.headers['set-cookie'], contains('unpub_session='));

        final adminRes = await http.get(
          staticBaseUri.resolve('/admin/tokens/me'),
          headers: {'authorization': 'Bearer static-secret'},
        );
        expect(adminRes.statusCode, HttpStatus.serviceUnavailable);
      } finally {
        await staticServer.close(force: true);
      }
    },
  );
}

class _MemoryMetaStore implements unpub.MetaStore {
  final unpub.UnpubPackage _package = unpub.UnpubPackage(
    'test_pkg',
    [
      unpub.UnpubVersion(
        '1.0.0',
        {'name': 'test_pkg', 'version': '1.0.0', 'description': 'test package'},
        null,
        'owner@example.com',
        null,
        null,
        DateTime.now().toUtc(),
      ),
    ],
    true,
    ['owner@example.com'],
    DateTime.now().toUtc(),
    DateTime.now().toUtc(),
    0,
  );

  @override
  Future<void> addUploader(String name, String email) async {}

  @override
  Future<void> addVersion(String name, unpub.UnpubVersion version) async {}

  @override
  void increaseDownloads(String name, String version) {}

  @override
  Future<unpub.UnpubPackage?> queryPackage(String name) async {
    return name == 'test_pkg' ? _package : null;
  }

  @override
  Future<unpub.UnpubQueryResult> queryPackages({
    required int size,
    required int page,
    required String sort,
    String? keyword,
    String? uploader,
    String? dependency,
  }) async {
    return unpub.UnpubQueryResult(1, [_package]);
  }

  @override
  Future<void> removeUploader(String name, String email) async {}
}

class _MemoryPackageStore extends unpub.PackageStore {
  @override
  Stream<List<int>> download(String name, String version) {
    return Stream.value(utf8.encode('fake-tarball'));
  }

  @override
  Future<void> upload(String name, String version, List<int> content) async {}
}
