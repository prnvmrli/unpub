import 'dart:async';
import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:unpub/src/models.dart';

import 'meta_store.dart';

final packageTable = 'packages';
final statsTable = 'package_stats';

class PostgreSqlMetaStore extends MetaStore {
  final PostgreSQLConnection _db;
  final Future<void> _ready;

  PostgreSqlMetaStore(this._db) : _ready = _ensureSchema(_db);

  static Future<void> _ensureSchema(PostgreSQLConnection db) async {
    await db.query('''
      CREATE TABLE IF NOT EXISTS $packageTable (
        name TEXT PRIMARY KEY,
        versions JSONB NOT NULL DEFAULT '[]'::jsonb,
        private BOOLEAN NOT NULL DEFAULT TRUE,
        uploaders TEXT[] NOT NULL DEFAULT ARRAY[]::text[],
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        download BIGINT NOT NULL DEFAULT 0
      )
    ''');
    await db.query('''
      CREATE TABLE IF NOT EXISTS $statsTable (
        name TEXT NOT NULL,
        day DATE NOT NULL,
        downloads BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (name, day)
      )
    ''');
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_packages_updated_at ON $packageTable(updated_at DESC)',
    );
    await db.query(
      'CREATE INDEX IF NOT EXISTS idx_packages_download ON $packageTable(download DESC)',
    );
  }

  @override
  Future<UnpubPackage?> queryPackage(String name) async {
    await _ready;
    final rows = await _db.query(
      '''
      SELECT name, versions, private, uploaders, created_at, updated_at, download
      FROM $packageTable
      WHERE name = @name
      LIMIT 1
      ''',
      substitutionValues: {'name': name},
    );
    if (rows.isEmpty) return null;
    return _rowToPackage(rows.first);
  }

  @override
  Future<void> addVersion(String name, UnpubVersion version) async {
    await _ready;
    await _db.query(
      '''
      INSERT INTO $packageTable (
        name,
        versions,
        uploaders,
        created_at,
        updated_at,
        private,
        download
      )
      VALUES (
        @name,
        @versions::jsonb,
        @uploaders::text[],
        @created_at,
        @updated_at,
        TRUE,
        0
      )
      ON CONFLICT (name) DO UPDATE SET
        versions = $packageTable.versions || EXCLUDED.versions,
        uploaders = ARRAY(
          SELECT DISTINCT item
          FROM unnest($packageTable.uploaders || @uploaders::text[]) AS item
        ),
        updated_at = EXCLUDED.updated_at
      ''',
      substitutionValues: {
        'name': name,
        'versions': jsonEncode([_jsonCompatible(version.toJson())]),
        'uploaders': version.uploader == null ? <String>[] : [version.uploader!],
        'created_at': version.createdAt.toUtc(),
        'updated_at': version.createdAt.toUtc(),
      },
    );
  }

  @override
  Future<void> addUploader(String name, String email) async {
    await _ready;
    await _db.query(
      '''
      UPDATE $packageTable
      SET uploaders = ARRAY(
        SELECT DISTINCT item
        FROM unnest(uploaders || ARRAY[@email]::text[]) AS item
      )
      WHERE name = @name
      ''',
      substitutionValues: {'name': name, 'email': email},
    );
  }

  @override
  Future<void> removeUploader(String name, String email) async {
    await _ready;
    await _db.query(
      '''
      UPDATE $packageTable
      SET uploaders = ARRAY(
        SELECT item
        FROM unnest(uploaders) AS item
        WHERE item <> @email
      )
      WHERE name = @name
      ''',
      substitutionValues: {'name': name, 'email': email},
    );
  }

  @override
  void increaseDownloads(String name, String version) {
    unawaited(_increaseDownloads(name));
  }

  Future<void> _increaseDownloads(String name) async {
    await _ready;
    await _db.query(
      '''
      UPDATE $packageTable
      SET download = download + 1
      WHERE name = @name
      ''',
      substitutionValues: {'name': name},
    );
    await _db.query(
      '''
      INSERT INTO $statsTable (name, day, downloads)
      VALUES (@name, CURRENT_DATE, 1)
      ON CONFLICT (name, day) DO UPDATE SET
        downloads = $statsTable.downloads + 1
      ''',
      substitutionValues: {'name': name},
    );
  }

  @override
  Future<UnpubQueryResult> queryPackages({
    required int size,
    required int page,
    required String sort,
    String? keyword,
    String? uploader,
    String? dependency,
  }) async {
    await _ready;
    final clauses = <String>[];
    final vars = <String, dynamic>{};

    if (keyword != null && keyword.trim().isNotEmpty) {
      clauses.add('name ILIKE @keyword');
      vars['keyword'] = '%${keyword.trim()}%';
    }
    if (uploader != null && uploader.trim().isNotEmpty) {
      clauses.add('@uploader = ANY(uploaders)');
      vars['uploader'] = uploader.trim();
    }
    if (dependency != null && dependency.trim().isNotEmpty) {
      clauses.add('''
        EXISTS (
          SELECT 1
          FROM jsonb_array_elements(versions) AS version
          WHERE (version->'pubspec'->'dependencies') ? @dependency
        )
      ''');
      vars['dependency'] = dependency.trim();
    }

    final whereClause = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final sortField = _resolveSortField(sort);
    final sortDirection = sortField == 'name' ? 'ASC' : 'DESC';

    final countRows = await _db.query(
      'SELECT COUNT(*) FROM $packageTable $whereClause',
      substitutionValues: vars,
    );
    final total = (countRows.first[0] as num).toInt();

    vars['limit'] = size;
    vars['offset'] = size * page;
    final rows = await _db.query('''
      SELECT name, versions, private, uploaders, created_at, updated_at, download
      FROM $packageTable
      $whereClause
      ORDER BY $sortField $sortDirection
      LIMIT @limit
      OFFSET @offset
      ''', substitutionValues: vars);

    return UnpubQueryResult(total, rows.map(_rowToPackage).toList());
  }

  String _resolveSortField(String sort) {
    switch (sort) {
      case 'updatedAt':
        return 'updated_at';
      case 'createdAt':
        return 'created_at';
      case 'name':
        return 'name';
      case 'download':
      default:
        return 'download';
    }
  }

  UnpubPackage _rowToPackage(PostgreSQLResultRow row) {
    final versionsValue = row[1];
    final versionsJson = versionsValue is String
        ? (jsonDecode(versionsValue) as List<dynamic>)
        : (versionsValue as List<dynamic>);
    final uploadersValue = row[3];
    final uploaders = (uploadersValue as List<dynamic>).cast<String>();

    return UnpubPackage(
      row[0] as String,
      versionsJson
          .map(
            (item) => UnpubVersion.fromJson(_restoreVersionDates(item as Map)),
          )
          .toList(),
      row[2] as bool,
      uploaders,
      (row[4] as DateTime).toUtc(),
      (row[5] as DateTime).toUtc(),
      (row[6] as num).toInt(),
    );
  }

  dynamic _jsonCompatible(dynamic value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _jsonCompatible(val)),
      );
    }
    if (value is List) {
      return value.map(_jsonCompatible).toList();
    }
    return value;
  }

  Map<String, dynamic> _restoreVersionDates(Map raw) {
    final value = raw.map(
      (key, val) => MapEntry(key.toString(), _restoreJsonValue(val)),
    );
    final createdAt = value['createdAt'];
    if (createdAt is String) {
      value['createdAt'] = DateTime.parse(createdAt).toUtc();
    }
    return value;
  }

  dynamic _restoreJsonValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _restoreJsonValue(val)),
      );
    }
    if (value is List) {
      return value.map(_restoreJsonValue).toList();
    }
    return value;
  }
}
