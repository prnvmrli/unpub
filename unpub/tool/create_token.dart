import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:postgres/postgres.dart';
import 'package:unpub/src/postgresql_connection.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'database',
      defaultsTo: 'postgresql://localhost:5432/dart_pub?sslmode=disable',
    )
    ..addOption('owner')
    ..addOption('token')
    ..addOption('expires-at');

  final results = parser.parse(args);
  final owner = (results['owner'] as String?)?.trim();
  if (owner == null || owner.isEmpty) {
    stderr.writeln('Missing required --owner');
    exit(2);
  }

  final tokenArg = (results['token'] as String?)?.trim();
  final token = (tokenArg == null || tokenArg.isEmpty)
      ? _generateToken()
      : tokenArg;
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

  final dbUri = (results['database'] as String).trim();
  final db = await openPostgreSqlConnection(dbUri);
  try {
    await _ensureSchema(db);
    await db.query(
      '''
      INSERT INTO api_keys (token, owner_name, status, expires_at)
      VALUES (@token, @owner, 'active', @expires_at)
      ''',
      substitutionValues: {
        'token': token,
        'owner': owner,
        'expires_at': expiresAt?.isEmpty == true ? null : expiresAt,
      },
    );

    print('Token created');
    print('  database: $dbUri');
    print('  owner: $owner');
    print('  token: $token');
    if (expiresAt != null && expiresAt.isNotEmpty) {
      print('  expires_at: $expiresAt');
    }
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

String _generateToken([int bytes = 32]) {
  final random = Random.secure();
  final data = List<int>.generate(bytes, (_) => random.nextInt(256));
  return base64Url.encode(data).replaceAll('=', '');
}
