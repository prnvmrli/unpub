import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import 'token_store.dart';

class PostgreSqlTokenStore implements TokenStore {
  final PostgreSQLConnection _db;
  final Future<void> _ready;

  PostgreSqlTokenStore(this._db) : _ready = _ensureSchema(_db);

  static Future<void> _ensureSchema(PostgreSQLConnection db) async {
    await db.query(r'''
      DO $$
      BEGIN
        CREATE TYPE user_role AS ENUM ('admin', 'developer', 'client');
      EXCEPTION
        WHEN duplicate_object THEN NULL;
      END $$;
    ''');

    await db.query('''
      CREATE TABLE IF NOT EXISTS users (
        id BIGSERIAL PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT,
        role user_role NOT NULL DEFAULT 'client',
        is_disabled BOOLEAN NOT NULL DEFAULT FALSE,
        disabled_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');
    await db.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT',
    );

    await db.query('''
      CREATE TABLE IF NOT EXISTS tokens (
        id BIGSERIAL PRIMARY KEY,
        user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        token_prefix TEXT NOT NULL UNIQUE,
        token_hash TEXT NOT NULL,
        can_download BOOLEAN NOT NULL DEFAULT TRUE,
        can_publish BOOLEAN NOT NULL DEFAULT FALSE,
        expires_at TIMESTAMPTZ,
        revoked BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        last_used_at TIMESTAMPTZ,
        CHECK (can_download OR can_publish)
      )
    ''');

    await db.query('''
      CREATE TABLE IF NOT EXISTS download_logs (
        id BIGSERIAL PRIMARY KEY,
        user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
        token_id BIGINT REFERENCES tokens(id) ON DELETE SET NULL,
        package_name TEXT NOT NULL,
        package_version TEXT,
        downloaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        client_ip INET,
        user_agent TEXT,
        success BOOLEAN NOT NULL DEFAULT TRUE
      )
    ''');

    await db.query('CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)');
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_users_is_disabled ON users(is_disabled)',
    );

    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_tokens_user_id ON tokens(user_id)',
    );
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_tokens_active_lookup ON tokens(token_prefix, revoked, expires_at)',
    );

    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_download_logs_user_downloaded_at ON download_logs(user_id, downloaded_at DESC)',
    );
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_download_logs_token_id ON download_logs(token_id)',
    );
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_download_logs_package_version ON download_logs(package_name, package_version)',
    );
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_download_logs_downloaded_at ON download_logs(downloaded_at DESC)',
    );

    await db.query(r'''
      CREATE OR REPLACE FUNCTION revoke_tokens_on_user_disable()
      RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.is_disabled = TRUE AND (OLD.is_disabled IS DISTINCT FROM TRUE) THEN
          NEW.disabled_at := COALESCE(NEW.disabled_at, NOW());

          UPDATE tokens
          SET revoked = TRUE
          WHERE user_id = NEW.id
            AND revoked = FALSE;
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    ''');

    await db.query('''
      DROP TRIGGER IF EXISTS trg_revoke_tokens_on_user_disable ON users;
      CREATE TRIGGER trg_revoke_tokens_on_user_disable
      BEFORE UPDATE OF is_disabled ON users
      FOR EACH ROW
      EXECUTE FUNCTION revoke_tokens_on_user_disable();
    ''');
  }

  @override
  Future<UserRecord?> authenticateUser({
    required String email,
    required String password,
  }) async {
    await _ready;

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return null;
    }

    final rows = await _db.query(
      '''
      SELECT id, email, role::text, is_disabled, password_hash, created_at, updated_at
      FROM users
      WHERE email = @email
      LIMIT 1
      ''',
      substitutionValues: {'email': normalizedEmail},
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final isDisabled = row[3] as bool;
    final passwordHash = row[4] as String?;
    if (isDisabled || passwordHash == null || passwordHash.isEmpty) {
      return null;
    }
    if (!BCrypt.checkpw(password, passwordHash)) {
      return null;
    }

    return UserRecord(
      id: (row[0] as num).toInt(),
      email: row[1] as String,
      role: row[2] as String,
      isDisabled: isDisabled,
      disabledAt: null,
      createdAt: _toRequiredIsoString(row[5]),
      updatedAt: _toRequiredIsoString(row[6]),
    );
  }

  @override
  Future<UserRecord?> findUserByEmail(String email) async {
    await _ready;
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return null;
    }

    final rows = await _db.query(
      '''
      SELECT id, email, role::text, is_disabled, created_at, updated_at
      FROM users
      WHERE email = @email
      LIMIT 1
      ''',
      substitutionValues: {'email': normalizedEmail},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return UserRecord(
      id: (row[0] as num).toInt(),
      email: row[1] as String,
      role: row[2] as String,
      isDisabled: row[3] as bool,
      disabledAt: null,
      createdAt: _toRequiredIsoString(row[4]),
      updatedAt: _toRequiredIsoString(row[5]),
    );
  }

  @override
  Future<List<UserRecord>> listUsers() async {
    await _ready;
    final rows = await _db.query('''
      SELECT id, email, role::text, is_disabled, disabled_at, created_at, updated_at
      FROM users
      ORDER BY id DESC
    ''');
    return rows
        .map(
          (row) => UserRecord(
            id: (row[0] as num).toInt(),
            email: row[1] as String,
            role: row[2] as String,
            isDisabled: row[3] as bool,
            disabledAt: _toIsoString(row[4]),
            createdAt: _toRequiredIsoString(row[5]),
            updatedAt: _toRequiredIsoString(row[6]),
          ),
        )
        .toList();
  }

  @override
  Future<bool> disableUser(int userId) async {
    await _ready;
    final rows = await _db.query(
      '''
      UPDATE users
      SET is_disabled = TRUE,
          updated_at = NOW()
      WHERE id = @id
        AND is_disabled = FALSE
      RETURNING id
      ''',
      substitutionValues: {'id': userId},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<UserRecord> createUser({
    required String email,
    required String password,
    required String role,
  }) async {
    await _ready;

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw ArgumentError('email is required');
    }

    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      throw ArgumentError('password is required');
    }

    final normalizedRole = role.trim().toLowerCase();
    if (!_validRoles.contains(normalizedRole)) {
      throw ArgumentError('invalid role: $role');
    }

    final rows = await _db.query(
      '''
      INSERT INTO users (username, email, password_hash, role)
      VALUES (@username, @email, @password_hash, @role::user_role)
      ON CONFLICT (email)
      DO UPDATE SET
        username = EXCLUDED.username,
        password_hash = EXCLUDED.password_hash,
        role = EXCLUDED.role,
        is_disabled = FALSE,
        disabled_at = NULL,
        updated_at = NOW()
      RETURNING id, email, role::text, is_disabled, created_at, updated_at
      ''',
      substitutionValues: {
        'username': normalizedEmail,
        'email': normalizedEmail,
        'password_hash': _hashPasswordBcrypt(normalizedPassword),
        'role': normalizedRole,
      },
    );

    final row = rows.first;
    return UserRecord(
      id: (row[0] as num).toInt(),
      email: row[1] as String,
      role: row[2] as String,
      isDisabled: row[3] as bool,
      disabledAt: null,
      createdAt: _toRequiredIsoString(row[4]),
      updatedAt: _toRequiredIsoString(row[5]),
    );
  }

  @override
  Future<TokenValidationRecord?> validateToken(String token) async {
    await _ready;
    final normalized = token.trim();
    final prefix = _extractPrefix(normalized);
    if (prefix == null) return null;

    final rows = await _db.query(
      '''
      SELECT t.id, t.user_id, u.username, t.token_hash, t.can_download, t.can_publish
      FROM tokens t
      INNER JOIN users u ON u.id = t.user_id
      WHERE t.token_prefix = @token_prefix
        AND t.revoked = FALSE
        AND (t.expires_at IS NULL OR t.expires_at > NOW())
        AND u.is_disabled = FALSE
      LIMIT 1
      ''',
      substitutionValues: {'token_prefix': prefix},
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final storedHash = row[3] as String;
    final actualHash = _sha256Hex(normalized);
    if (!_constantTimeEquals(storedHash, actualHash)) {
      return null;
    }

    return TokenValidationRecord(
      tokenId: (row[0] as num).toInt(),
      userId: (row[1] as num).toInt(),
      ownerName: row[2] as String,
      canDownload: row[4] as bool,
      canPublish: row[5] as bool,
    );
  }

  @override
  Future<bool> isValidToken(String token) async {
    final validated = await validateToken(token);
    return validated != null;
  }

  @override
  Future<void> markTokenUsed({required int tokenId}) async {
    await _ready;
    await _db.query(
      '''
      UPDATE tokens
      SET last_used_at = NOW()
      WHERE id = @id
      ''',
      substitutionValues: {'id': tokenId},
    );
  }

  @override
  Future<void> logDownload({
    required int tokenId,
    required int userId,
    required String packageName,
    required String version,
    required String? ipAddress,
  }) async {
    await _ready;
    await _db.query(
      '''
      INSERT INTO download_logs (user_id, token_id, package_name, package_version, client_ip)
      VALUES (@user_id, @token_id, @package_name, @package_version, @client_ip)
      ''',
      substitutionValues: {
        'user_id': userId,
        'token_id': tokenId,
        'package_name': packageName,
        'package_version': version,
        'client_ip': ipAddress,
      },
    );
  }

  @override
  Future<ApiKeyRecord> createToken({
    required String ownerName,
    required String name,
    String? expiresAt,
    bool canDownload = true,
    bool canPublish = false,
  }) async {
    await _ready;

    if (!canDownload && !canPublish) {
      throw ArgumentError('token must have at least one permission');
    }

    final userRows = await _db.query(
      '''
      INSERT INTO users (username, email, role)
      VALUES (@owner_name, @email, 'developer')
      ON CONFLICT (username)
      DO UPDATE SET username = EXCLUDED.username
      RETURNING id, username
      ''',
      substitutionValues: {'owner_name': ownerName, 'email': ownerName},
    );
    final userId = (userRows.first[0] as num).toInt();
    final owner = userRows.first[1] as String;

    final rawToken = _generateToken();
    final tokenName = name.trim().isEmpty
        ? 'token-${DateTime.now().toUtc().millisecondsSinceEpoch}'
        : name.trim();
    final row = await _storeTokenRecord(
      token: rawToken,
      userId: userId,
      canDownload: canDownload,
      canPublish: canPublish,
      expiresAt: _parseTimestamp(expiresAt),
      name: tokenName,
    );
    return ApiKeyRecord(
      id: (row[0] as num).toInt(),
      name: row[2] as String,
      token: rawToken,
      userId: (row[1] as num).toInt(),
      ownerName: owner,
      status: (row[6] as bool) ? 'revoked' : 'active',
      canDownload: row[4] as bool,
      canPublish: row[5] as bool,
      revoked: row[6] as bool,
      createdAt: _toRequiredIsoString(row[7]),
      expiresAt: _toIsoString(row[8]),
      lastUsedAt: _toIsoString(row[9]),
    );
  }

  Future<PostgreSQLResultRow> _storeTokenRecord({
    required String token,
    required int userId,
    required bool canDownload,
    required bool canPublish,
    required DateTime? expiresAt,
    required String name,
  }) async {
    final prefix = _extractPrefix(token);
    if (prefix == null) {
      throw ArgumentError('invalid token format');
    }

    final rows = await _db.query(
      '''
      INSERT INTO tokens (
        user_id,
        name,
        token_prefix,
        token_hash,
        can_download,
        can_publish,
        expires_at,
        revoked
      )
      VALUES (
        @user_id,
        @name,
        @token_prefix,
        @token_hash,
        @can_download,
        @can_publish,
        @expires_at,
        FALSE
      )
      RETURNING id, user_id, name, token_prefix, can_download, can_publish, revoked, created_at, expires_at, last_used_at
      ''',
      substitutionValues: {
        'user_id': userId,
        'name': name,
        'token_prefix': prefix,
        'token_hash': _sha256Hex(token),
        'can_download': canDownload,
        'can_publish': canPublish,
        'expires_at': expiresAt,
      },
    );
    return rows.first;
  }

  @override
  Future<List<ApiKeyRecord>> listTokens({String? ownerName}) async {
    await _ready;

    final rows = ownerName == null
        ? await _db.query('''
            SELECT t.id, t.name, t.user_id, u.username, t.token_prefix, t.can_download, t.can_publish, t.revoked, t.created_at, t.expires_at, t.last_used_at
            FROM tokens t
            INNER JOIN users u ON u.id = t.user_id
            ORDER BY t.id DESC
            ''')
        : await _db.query(
            '''
            SELECT t.id, t.name, t.user_id, u.username, t.token_prefix, t.can_download, t.can_publish, t.revoked, t.created_at, t.expires_at, t.last_used_at
            FROM tokens t
            INNER JOIN users u ON u.id = t.user_id
            WHERE u.username = @owner_name
            ORDER BY t.id DESC
            ''',
            substitutionValues: {'owner_name': ownerName},
          );

    return rows.map((row) {
      final revoked = row[7] as bool;
      return ApiKeyRecord(
        id: (row[0] as num).toInt(),
        name: row[1] as String,
        userId: (row[2] as num).toInt(),
        ownerName: row[3] as String,
        token: '${row[4]}_***',
        status: revoked ? 'revoked' : 'active',
        canDownload: row[5] as bool,
        canPublish: row[6] as bool,
        revoked: revoked,
        createdAt: _toRequiredIsoString(row[8]),
        expiresAt: _toIsoString(row[9]),
        lastUsedAt: _toIsoString(row[10]),
      );
    }).toList();
  }

  @override
  Future<bool> revokeToken({required int id, String? ownerName}) async {
    await _ready;

    final rows = ownerName == null
        ? await _db.query(
            '''
            UPDATE tokens t
            SET revoked = TRUE
            WHERE t.id = @id
            RETURNING t.id
            ''',
            substitutionValues: {'id': id},
          )
        : await _db.query(
            '''
            UPDATE tokens t
            SET revoked = TRUE
            FROM users u
            WHERE t.id = @id
              AND t.user_id = u.id
              AND u.username = @owner_name
            RETURNING t.id
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
            SELECT d.id, d.token_id, d.user_id, t.token_prefix, d.package_name, COALESCE(d.package_version, ''), d.downloaded_at, d.client_ip::text
            FROM download_logs d
            LEFT JOIN tokens t ON t.id = d.token_id
            ORDER BY d.id DESC
            LIMIT @limit
            ''',
            substitutionValues: {'limit': safeLimit},
          )
        : await _db.query(
            '''
            SELECT d.id, d.token_id, d.user_id, t.token_prefix, d.package_name, COALESCE(d.package_version, ''), d.downloaded_at, d.client_ip::text
            FROM download_logs d
            INNER JOIN users u ON u.id = d.user_id
            LEFT JOIN tokens t ON t.id = d.token_id
            WHERE u.username = @owner_name
            ORDER BY d.id DESC
            LIMIT @limit
            ''',
            substitutionValues: {'owner_name': ownerName, 'limit': safeLimit},
          );

    return rows
        .map(
          (row) => DownloadRecord(
            id: (row[0] as num).toInt(),
            tokenId: (row[1] as num?)?.toInt() ?? 0,
            userId: (row[2] as num?)?.toInt(),
            tokenPrefix: row[3] == null ? 'unknown' : '${row[3]}_***',
            packageName: row[4] as String,
            version: row[5] as String,
            timestamp: _toRequiredIsoString(row[6]),
            ipAddress: row[7] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<String?> ownerByToken(String token) async {
    final validated = await validateToken(token);
    return validated?.ownerName;
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
    final randomPart = base64Url.encode(data).replaceAll('=', '');
    final prefix = randomPart.substring(0, 8);
    return '${prefix}_$randomPart';
  }

  String? _extractPrefix(String token) {
    final normalized = token.trim();
    if (normalized.length < 8) return null;

    final sepIndex = normalized.indexOf('_');
    if (sepIndex == -1) {
      return normalized.substring(0, 8);
    }
    if (sepIndex < 8) return null;

    return normalized.substring(0, 8);
  }

  String _sha256Hex(String value) {
    final digest = sha256.convert(utf8.encode(value));
    return digest.toString();
  }

  String _hashPasswordBcrypt(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static const Set<String> _validRoles = {'admin', 'developer', 'client'};
}
