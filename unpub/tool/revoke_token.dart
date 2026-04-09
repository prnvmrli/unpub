import 'dart:io';

import 'package:args/args.dart';
import 'package:postgres/postgres.dart';
import 'package:unpub/src/postgresql_connection.dart';

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
    await _ensureSchema(db);
    final existing = await db.query(
      'SELECT id, status FROM api_keys WHERE token = @token LIMIT 1',
      substitutionValues: {'token': token},
    );
    if (existing.isEmpty) {
      stderr.writeln('Token not found');
      exit(3);
    }

    await db.query(
      '''
      UPDATE api_keys
      SET status = 'revoked'
      WHERE token = @token
      ''',
      substitutionValues: {'token': token},
    );

    print('Token revoked');
    print('  database: $dbUri');
    print('  token: $token');
  } finally {
    await db.close();
  }
}

Future<void> _ensureSchema(PostgreSQLConnection db) async {
  await db.query('''
    CREATE TABLE IF NOT EXISTS api_keys (
      id BIGSERIAL PRIMARY KEY,
      token TEXT NOT NULL UNIQUE,
      owner_name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ,
      last_used_at TIMESTAMPTZ
    )
  ''');
  await db.query(
    'CREATE INDEX IF NOT EXISTS idx_api_keys_token ON api_keys(token)',
  );
  await db.query(
    'CREATE INDEX IF NOT EXISTS idx_api_keys_status ON api_keys(status)',
  );
}
