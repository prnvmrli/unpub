import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';

import 'token_store.dart';

class PostgreSqlTokenStore implements TokenStore {
  final PostgreSQLConnection _db;
  final Future<void> _ready;

  PostgreSqlTokenStore(this._db) : _ready = _ensureSchema(_db);

  static Future<void> _ensureSchema(PostgreSQLConnection db) async {
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
    await db.query('''
      CREATE TABLE IF NOT EXISTS downloads (
        id BIGSERIAL PRIMARY KEY,
        token TEXT NOT NULL,
        package_name TEXT NOT NULL,
        version TEXT NOT NULL,
        timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        ip_address TEXT
      )
    ''');
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_downloads_token ON downloads(token)',
    );
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_downloads_package ON downloads(package_name)',
    );
  }

  @override
  Future<bool> isValidToken(String token) async {
    await _ready;
    final rows = await _db.query(
      '''
      SELECT id
      FROM api_keys
      WHERE token = @token
        AND status = 'active'
        AND (expires_at IS NULL OR expires_at > NOW())
      LIMIT 1
      ''',
      substitutionValues: {'token': token},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> markTokenUsed(String token) async {
    await _ready;
    await _db.query(
      '''
      UPDATE api_keys
      SET last_used_at = NOW()
      WHERE token = @token
      ''',
      substitutionValues: {'token': token},
    );
  }

  @override
  Future<void> logDownload({
    required String token,
    required String packageName,
    required String version,
    required String? ipAddress,
  }) async {
    await _ready;
    await _db.query(
      '''
      INSERT INTO downloads (token, package_name, version, ip_address)
      VALUES (@token, @package_name, @version, @ip_address)
      ''',
      substitutionValues: {
        'token': token,
        'package_name': packageName,
        'version': version,
        'ip_address': ipAddress,
      },
    );
  }

  @override
  Future<ApiKeyRecord> createToken({
    required String ownerName,
    String? expiresAt,
  }) async {
    await _ready;
    final token = _generateToken();
    final rows = await _db.query(
      '''
      INSERT INTO api_keys (token, owner_name, status, expires_at)
      VALUES (@token, @owner_name, 'active', @expires_at)
      RETURNING id, token, owner_name, status, created_at, expires_at, last_used_at
      ''',
      substitutionValues: {
        'token': token,
        'owner_name': ownerName,
        'expires_at': _parseTimestamp(expiresAt),
      },
    );
    return _fromApiKeyRow(rows.first);
  }

  @override
  Future<List<ApiKeyRecord>> listTokens({String? ownerName}) async {
    await _ready;
    final rows = ownerName == null
        ? await _db.query('''
            SELECT id, token, owner_name, status, created_at, expires_at, last_used_at
            FROM api_keys
            ORDER BY id DESC
            ''')
        : await _db.query(
            '''
            SELECT id, token, owner_name, status, created_at, expires_at, last_used_at
            FROM api_keys
            WHERE owner_name = @owner_name
            ORDER BY id DESC
            ''',
            substitutionValues: {'owner_name': ownerName},
          );
    return rows.map(_fromApiKeyRow).toList();
  }

  @override
  Future<bool> revokeToken({required int id, String? ownerName}) async {
    await _ready;
    final rows = ownerName == null
        ? await _db.query(
            '''
            UPDATE api_keys
            SET status = 'revoked'
            WHERE id = @id
            RETURNING id
            ''',
            substitutionValues: {'id': id},
          )
        : await _db.query(
            '''
            UPDATE api_keys
            SET status = 'revoked'
            WHERE id = @id
              AND owner_name = @owner_name
            RETURNING id
            ''',
            substitutionValues: {'id': id, 'owner_name': ownerName},
          );
    return rows.isNotEmpty;
  }

  @override
  Future<List<DownloadRecord>> listDownloads({
    String? ownerName,
    int limit = 100,
  }) async {
    await _ready;
    final safeLimit = limit < 1 ? 1 : (limit > 500 ? 500 : limit);
    final rows = ownerName == null
        ? await _db.query(
            '''
            SELECT d.id, d.token, d.package_name, d.version, d.timestamp, d.ip_address
            FROM downloads d
            ORDER BY d.id DESC
            LIMIT @limit
            ''',
            substitutionValues: {'limit': safeLimit},
          )
        : await _db.query(
            '''
            SELECT d.id, d.token, d.package_name, d.version, d.timestamp, d.ip_address
            FROM downloads d
            INNER JOIN api_keys k ON k.token = d.token
            WHERE k.owner_name = @owner_name
            ORDER BY d.id DESC
            LIMIT @limit
            ''',
            substitutionValues: {'owner_name': ownerName, 'limit': safeLimit},
          );
    return rows
        .map(
          (row) => DownloadRecord(
            id: (row[0] as num).toInt(),
            token: row[1] as String,
            packageName: row[2] as String,
            version: row[3] as String,
            timestamp: _toRequiredIsoString(row[4]),
            ipAddress: row[5] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<String?> ownerByToken(String token) async {
    await _ready;
    final rows = await _db.query(
      '''
      SELECT owner_name
      FROM api_keys
      WHERE token = @token
        AND status = 'active'
        AND (expires_at IS NULL OR expires_at > NOW())
      LIMIT 1
      ''',
      substitutionValues: {'token': token},
    );
    if (rows.isEmpty) return null;
    return rows.first[0] as String;
  }

  ApiKeyRecord _fromApiKeyRow(PostgreSQLResultRow row) {
    return ApiKeyRecord(
      id: (row[0] as num).toInt(),
      token: row[1] as String,
      ownerName: row[2] as String,
      status: row[3] as String,
      createdAt: _toRequiredIsoString(row[4]),
      expiresAt: _toIsoString(row[5]),
      lastUsedAt: _toIsoString(row[6]),
    );
  }

  DateTime? _parseTimestamp(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.parse(value).toUtc();
  }

  String? _toIsoString(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value.toString();
  }

  String _toRequiredIsoString(dynamic value) {
    final iso = _toIsoString(value);
    if (iso == null) {
      throw StateError('Expected non-null timestamp from database');
    }
    return iso;
  }

  String _generateToken([int bytes = 32]) {
    final random = Random.secure();
    final data = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }
}
