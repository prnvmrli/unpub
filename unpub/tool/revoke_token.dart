import 'dart:io';

import 'package:args/args.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('db-path', defaultsTo: './unpub-tokens.db')
    ..addOption('token');

  final results = parser.parse(args);
  final token = (results['token'] as String?)?.trim();
  if (token == null || token.isEmpty) {
    stderr.writeln('Missing required --token');
    exit(2);
  }

  final dbPath = (results['db-path'] as String).trim();
  final db = sqlite3.open(dbPath);
  try {
    _ensureSchema(db);
    final existing = db.select(
      'SELECT id, status FROM api_keys WHERE token = ? LIMIT 1',
      [token],
    );
    if (existing.isEmpty) {
      stderr.writeln('Token not found');
      exit(3);
    }

    db.execute(
      '''
      UPDATE api_keys
      SET status = 'revoked'
      WHERE token = ?
      ''',
      [token],
    );

    print('Token revoked');
    print('  db: $dbPath');
    print('  token: $token');
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
