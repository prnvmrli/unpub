import 'dart:io';

import 'package:args/args.dart';
import 'package:unpub/src/postgresql_connection.dart';
import 'package:unpub/src/postgresql_token_store.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'database',
      defaultsTo: 'postgresql://localhost:5432/dart_pub?sslmode=disable',
    )
    ..addOption('owner')
    ..addOption('expires-at')
    ..addFlag('can-download', defaultsTo: true)
    ..addFlag('can-publish', defaultsTo: false);

  final results = parser.parse(args);
  final owner = (results['owner'] as String?)?.trim();
  if (owner == null || owner.isEmpty) {
    stderr.writeln('Missing required --owner');
    exit(2);
  }

  final expiresAt = (results['expires-at'] as String?)?.trim();
  if (expiresAt != null && expiresAt.isNotEmpty) {
    try {
      DateTime.parse(expiresAt);
    } catch (_) {
      stderr.writeln(
        'Invalid --expires-at (use ISO-8601, e.g. 2027-01-01T00:00:00Z)',
      );
      exit(2);
    }
  }

  final canDownload = results['can-download'] as bool;
  final canPublish = results['can-publish'] as bool;
  if (!canDownload && !canPublish) {
    stderr.writeln('At least one permission is required');
    exit(2);
  }

  final dbUri = (results['database'] as String).trim();
  final db = await openPostgreSqlConnection(dbUri);
  try {
    final tokenStore = PostgreSqlTokenStore(db);
    final created = await tokenStore.createToken(
      ownerName: owner,
      name: 'cli-token',
      expiresAt: expiresAt?.isEmpty == true ? null : expiresAt,
      canDownload: canDownload,
      canPublish: canPublish,
    );

    print('Token created');
    print('  database: $dbUri');
    print('  owner: $owner');
    print('  user_id: ${created.userId}');
    print('  token: ${created.token}');
    print('  can_download: ${created.canDownload}');
    print('  can_publish: ${created.canPublish}');
    if (created.expiresAt != null && created.expiresAt!.isNotEmpty) {
      print('  expires_at: ${created.expiresAt}');
    }
  } finally {
    await db.close();
  }
}
