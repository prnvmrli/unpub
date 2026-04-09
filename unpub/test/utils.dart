import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:unpub/unpub.dart' as unpub;
import 'package:postgres/postgres.dart';

final notExistingPacakge = 'not_existing_package';
final baseDir = path.absolute('unpub-packages');
final pubHostedUrl = 'http://localhost:4000';
final baseUri = Uri.parse(pubHostedUrl);

final package0 = 'package_0';
final package1 = 'package_1';
final email0 = 'email0@example.com';
final email1 = 'email1@example.com';
final email2 = 'email2@example.com';
final email3 = 'email3@example.com';

String resolveTestDatabaseUri({String? databaseName}) {
  final fromEnv = Platform.environment['UNPUB_TEST_DB_URI']?.trim();
  final baseUri = (fromEnv != null && fromEnv.isNotEmpty)
      ? Uri.parse(fromEnv)
      : Uri.parse('postgresql://localhost:5432/dart_pub_test?sslmode=disable');
  if (databaseName == null || databaseName.trim().isEmpty) {
    return baseUri.toString();
  }
  final safeDbName = databaseName.trim();
  return baseUri.replace(path: '/$safeDbName').toString();
}

Future<PostgreSQLConnection> openTestDb({
  String databaseName = 'dart_pub_test',
}) async {
  await ensureTestDatabase(databaseName);
  return unpub.openPostgreSqlConnection(
    resolveTestDatabaseUri(databaseName: databaseName),
  );
}

Future<void> ensureTestDatabase(String databaseName) async {
  final validName = RegExp(r'^[a-zA-Z0-9_]+$');
  if (!validName.hasMatch(databaseName)) {
    throw ArgumentError('Invalid database name: $databaseName');
  }
  final baseUri = Uri.parse(resolveTestDatabaseUri());
  final adminUri = baseUri.replace(path: '/postgres');
  final adminDb = await unpub.openPostgreSqlConnection(adminUri.toString());
  try {
    final rows = await adminDb.query(
      'SELECT 1 FROM pg_database WHERE datname = @db LIMIT 1',
      substitutionValues: {'db': databaseName},
    );
    if (rows.isEmpty) {
      await adminDb.query('CREATE DATABASE "$databaseName"');
    }
  } finally {
    await adminDb.close();
  }
}

Future<void> resetMetaTables(PostgreSQLConnection db) async {
  await db.query('DROP TABLE IF EXISTS ${unpub.statsTable}');
  await db.query('DROP TABLE IF EXISTS ${unpub.packageTable}');
}

Future<HttpServer> createServer(String opEmail, PostgreSQLConnection db) async {
  final store = unpub.PostgreSqlMetaStore(db);

  var app = unpub.App(
    metaStore: store,
    packageStore: unpub.FileStore(baseDir),
    overrideUploaderEmail: opEmail,
  );

  var server = await app.serve('0.0.0.0', 4000);
  return server;
}

Future<http.Response> getVersions(String package) {
  package = Uri.encodeComponent(package);
  return http.get(baseUri.resolve('/api/packages/$package'));
}

Future<http.Response> getSpecificVersion(String package, String version) {
  package = Uri.encodeComponent(package);
  version = Uri.encodeComponent(version);
  return http.get(baseUri.resolve('/api/packages/$package/versions/$version'));
}

Future<ProcessResult> pubPublish(String name, String version) async {
  final fixtureDir = Directory(path.absolute('test/fixtures', name, version));
  if (!fixtureDir.existsSync()) {
    return ProcessResult(0, 2, '', 'fixture not found: ${fixtureDir.path}');
  }

  final archive = Archive();
  for (final entity in fixtureDir.listSync()) {
    if (entity is! File) continue;
    final bytes = await entity.readAsBytes();
    archive.addFile(
      ArchiveFile(path.basename(entity.path), bytes.length, bytes),
    );
  }
  final tarBytes = TarEncoder().encode(archive);
  final gzBytes = GZipEncoder().encode(tarBytes);

  final uploadReq =
      http.MultipartRequest(
          'POST',
          baseUri.resolve('/api/packages/versions/newUpload'),
        )
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            gzBytes,
            filename: '$name-$version.tar.gz',
            contentType: MediaType('application', 'gzip'),
          ),
        );
  final uploadRes = await uploadReq.send();
  final location = uploadRes.headers['location'] ?? '';
  if (uploadRes.statusCode == HttpStatus.found && location.isNotEmpty) {
    final uri = Uri.parse(location);
    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      return ProcessResult(0, 1, '', Uri.decodeQueryComponent(error));
    }
    return ProcessResult(0, 0, '', '');
  }

  final body = await uploadRes.stream.bytesToString();
  return ProcessResult(
    0,
    1,
    '',
    'upload failed with status ${uploadRes.statusCode}: $body',
  );
}

Future<ProcessResult> pubUploader(
  String name,
  String operation,
  String email,
) async {
  assert(['add', 'remove'].contains(operation), 'operation error');

  final encodedName = Uri.encodeComponent(name);
  final encodedEmail = Uri.encodeComponent(email);
  late http.Response res;
  if (operation == 'add') {
    res = await http.post(
      baseUri.resolve('/api/packages/$encodedName/uploaders'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: 'email=$encodedEmail',
    );
  } else {
    res = await http.delete(
      baseUri.resolve('/api/packages/$encodedName/uploaders/$encodedEmail'),
    );
  }

  if (res.statusCode >= 200 && res.statusCode < 300) {
    return ProcessResult(0, 0, '', '');
  }

  final message = _extractErrorMessage(res.body);
  return ProcessResult(0, 1, '', message ?? res.body);
}

String? _extractErrorMessage(String body) {
  try {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String) return message;
      }
    }
  } catch (_) {}
  return null;
}
