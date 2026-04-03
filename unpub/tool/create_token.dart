import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('db-path', defaultsTo: './unpub-tokens.db')
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

  final dbPath = (results['db-path'] as String).trim();
  final db = sqlite3.open(dbPath);
  try {
    _ensureSchema(db);
    db.execute(
      '''
      INSERT INTO api_keys (token, owner_name, status, expires_at)
      VALUES (?, ?, 'active', ?)
      ''',
      [token, owner, expiresAt?.isEmpty == true ? null : expiresAt],
    );

    print('Token created');
    print('  db: $dbPath');
    print('  owner: $owner');
    print('  token: $token');
    if (expiresAt != null && expiresAt.isNotEmpty) {
      print('  expires_at: $expiresAt');
    }
  } finally {
    db.close();
  }
}

void _ensureSchema(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS api_keys (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      token TEXT NOT NULL UNIQUE,
      owner_name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      expires_at TEXT,
      last_used_at TEXT
    )
  ''');
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_api_keys_token ON api_keys(token)',
  );
  db.execute(
    'CREATE INDEX IF NOT EXISTS idx_api_keys_status ON api_keys(status)',
  );
}

String _generateToken([int bytes = 32]) {
  final random = Random.secure();
  final data = List<int>.generate(bytes, (_) => random.nextInt(256));
  return base64Url.encode(data).replaceAll('=', '');
}
