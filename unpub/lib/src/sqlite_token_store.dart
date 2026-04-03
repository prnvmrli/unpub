import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'token_store.dart';

class SqliteTokenStore implements TokenStore {
  final Database _db;

  SqliteTokenStore(String dbPath) : _db = sqlite3.open(dbPath) {
    _db.execute('''
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
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_api_keys_token ON api_keys(token)',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_api_keys_status ON api_keys(status)',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        token TEXT NOT NULL,
        "package" TEXT NOT NULL,
        version TEXT NOT NULL,
        timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ip_address TEXT
      )
    ''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_downloads_token ON downloads(token)',
    );
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_downloads_package ON downloads("package")',
    );
  }

  @override
  Future<bool> isValidToken(String token) async {
    final rows = _db.select(
      '''
      SELECT id
      FROM api_keys
      WHERE token = ?
        AND status = 'active'
        AND (expires_at IS NULL OR datetime(expires_at) > datetime('now'))
      LIMIT 1
      ''',
      [token],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> markTokenUsed(String token) async {
    _db.execute(
      '''
      UPDATE api_keys
      SET last_used_at = CURRENT_TIMESTAMP
      WHERE token = ?
      ''',
      [token],
    );
  }

  @override
  Future<void> logDownload({
    required String token,
    required String packageName,
    required String version,
    required String? ipAddress,
  }) async {
    _db.execute(
      '''
      INSERT INTO downloads (token, "package", version, ip_address)
      VALUES (?, ?, ?, ?)
      ''',
      [token, packageName, version, ipAddress],
    );
  }

  @override
  Future<ApiKeyRecord> createToken({
    required String ownerName,
    String? expiresAt,
  }) async {
    final token = _generateToken();
    _db.execute(
      '''
      INSERT INTO api_keys (token, owner_name, status, expires_at)
      VALUES (?, ?, 'active', ?)
      ''',
      [token, ownerName, expiresAt],
    );
    final row = _db
        .select(
          '''
      SELECT id, token, owner_name, status, created_at, expires_at, last_used_at
      FROM api_keys
      WHERE token = ?
      LIMIT 1
      ''',
          [token],
        )
        .first;
    return _fromRow(row);
  }

  @override
  Future<List<ApiKeyRecord>> listTokens({String? ownerName}) async {
    final rows = ownerName == null
        ? _db.select('''
            SELECT id, token, owner_name, status, created_at, expires_at, last_used_at
            FROM api_keys
            ORDER BY id DESC
            ''')
        : _db.select(
            '''
            SELECT id, token, owner_name, status, created_at, expires_at, last_used_at
            FROM api_keys
            WHERE owner_name = ?
            ORDER BY id DESC
            ''',
            [ownerName],
          );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<bool> revokeToken({required int id, String? ownerName}) async {
    final rows = ownerName == null
        ? _db.select('SELECT id FROM api_keys WHERE id = ? LIMIT 1', [id])
        : _db.select(
            'SELECT id FROM api_keys WHERE id = ? AND owner_name = ? LIMIT 1',
            [id, ownerName],
          );
    if (rows.isEmpty) return false;
    _db.execute(
      '''
      UPDATE api_keys
      SET status = 'revoked'
      WHERE id = ?
      ''',
      [id],
    );
    return true;
  }

  @override
  Future<List<DownloadRecord>> listDownloads({
    String? ownerName,
    int limit = 100,
  }) async {
    final safeLimit = limit < 1 ? 1 : (limit > 500 ? 500 : limit);
    final rows = ownerName == null
        ? _db.select(
            '''
            SELECT d.id, d.token, d."package", d.version, d.timestamp, d.ip_address
            FROM downloads d
            ORDER BY d.id DESC
            LIMIT ?
            ''',
            [safeLimit],
          )
        : _db.select(
            '''
            SELECT d.id, d.token, d."package", d.version, d.timestamp, d.ip_address
            FROM downloads d
            INNER JOIN api_keys k ON k.token = d.token
            WHERE k.owner_name = ?
            ORDER BY d.id DESC
            LIMIT ?
            ''',
            [ownerName, safeLimit],
          );
    return rows
        .map(
          (row) => DownloadRecord(
            id: row['id'] as int,
            token: row['token'] as String,
            packageName: row['package'] as String,
            version: row['version'] as String,
            timestamp: row['timestamp'] as String,
            ipAddress: row['ip_address'] as String?,
          ),
        )
        .toList();
  }

  ApiKeyRecord _fromRow(Row row) {
    return ApiKeyRecord(
      id: row['id'] as int,
      token: row['token'] as String,
      ownerName: row['owner_name'] as String,
      status: row['status'] as String,
      createdAt: row['created_at'] as String,
      expiresAt: row['expires_at'] as String?,
      lastUsedAt: row['last_used_at'] as String?,
    );
  }

  String _generateToken([int bytes = 32]) {
    final random = Random.secure();
    final data = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }
}
