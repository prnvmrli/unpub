import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:unpub/unpub.dart' as unpub;

void main() {
  late Db db;
  late HttpServer server;
  late Uri baseUri;
  late Directory packageDir;

  setUpAll(() async {
    db = Db('mongodb://localhost:27017/dart_pub_http_test');
    await db.open();
    packageDir = Directory.systemTemp.createTempSync('unpub-http-test-');

    final app = unpub.App(
      metaStore: unpub.MongoStore(db),
      packageStore: unpub.FileStore(packageDir.path),
      overrideUploaderEmail: 'http-test@example.com',
    );
    server = await app.serve('127.0.0.1', 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await db.dropCollection(unpub.packageCollection);
    await db.dropCollection(unpub.statsCollection);
    await db.close();
    await server.close(force: true);
    if (packageDir.existsSync()) {
      packageDir.deleteSync(recursive: true);
    }
  });

  test('upload and get package metadata over HTTP', () async {
    await db.dropCollection(unpub.packageCollection);
    await db.dropCollection(unpub.statsCollection);

    final tarGzBytes = await _buildFixtureTarGz(
      'package_0',
      '0.0.1',
      const ['pubspec.yaml', 'README.md', 'CHANGELOG.md', 'LICENSE'],
    );

    final uploadReq = http.MultipartRequest(
      'POST',
      baseUri.resolve('/api/packages/versions/newUpload'),
    )
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          tarGzBytes,
          filename: 'package_0-0.0.1.tar.gz',
          contentType: MediaType('application', 'gzip'),
        ),
      );

    final uploadRes = await uploadReq.send();
    expect(uploadRes.statusCode, 302);
    expect(uploadRes.headers['location'], isNotNull);
    expect(uploadRes.headers['location']!, contains('newUploadFinish'));
    expect(uploadRes.headers['location']!, isNot(contains('error=')));

    final versionsRes = await http.get(baseUri.resolve('/api/packages/package_0'));
    expect(versionsRes.statusCode, 200);
    final versionsBody = json.decode(versionsRes.body) as Map<String, dynamic>;
    expect(versionsBody['name'], 'package_0');
    expect((versionsBody['latest'] as Map<String, dynamic>)['version'], '0.0.1');
    expect((versionsBody['versions'] as List).length, 1);

    final versionRes =
        await http.get(baseUri.resolve('/api/packages/package_0/versions/0.0.1'));
    expect(versionRes.statusCode, 200);
    final versionBody = json.decode(versionRes.body) as Map<String, dynamic>;
    expect(versionBody['version'], '0.0.1');

    // Duplicate upload should fail with expected redirect error.
    final duplicateReq = http.MultipartRequest(
      'POST',
      baseUri.resolve('/api/packages/versions/newUpload'),
    )
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          tarGzBytes,
          filename: 'package_0-0.0.1.tar.gz',
          contentType: MediaType('application', 'gzip'),
        ),
      );
    final duplicateRes = await duplicateReq.send();
    expect(duplicateRes.statusCode, 302);
    expect(duplicateRes.headers['location'], contains('error='));
    expect(duplicateRes.headers['location'], contains('version%20invalid'));
  });
}

Future<List<int>> _buildFixtureTarGz(
    String package, String version, List<String> files) async {
  final fixtureRoot = path.absolute('test', 'fixtures', package, version);

  final archive = Archive();
  for (final filename in files) {
    final filePath = path.join(fixtureRoot, filename);
    final bytes = await File(filePath).readAsBytes();
    archive.addFile(ArchiveFile(filename, bytes.length, bytes));
  }

  final tarBytes = TarEncoder().encode(archive)!;
  final gzBytes = GZipEncoder().encode(tarBytes)!;
  return gzBytes;
}
