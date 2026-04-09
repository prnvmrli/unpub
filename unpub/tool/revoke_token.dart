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
    ..addOption('token');

  final results = parser.parse(args);
  final token = (results['token'] as String?)?.trim();
  if (token == null || token.isEmpty) {
    stderr.writeln('Missing required --token');
    exit(2);
  }

  final dbUri = (results['database'] as String).trim();
  final db = await openPostgreSqlConnection(dbUri);
  try {
    final tokenStore = PostgreSqlTokenStore(db);
    final validated = await tokenStore.validateToken(token);
    if (validated == null) {
      stderr.writeln('Token not found or already invalid');
      exit(3);
    }

    final revoked = await tokenStore.revokeToken(id: validated.tokenId);
    if (!revoked) {
      stderr.writeln('Token not found');
      exit(3);
    }

    print('Token revoked');
    print('  database: $dbUri');
    print('  token_id: ${validated.tokenId}');
    print('  token_prefix: ${token.substring(0, 8)}');
  } finally {
    await db.close();
  }
}
