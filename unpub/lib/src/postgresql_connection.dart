import 'dart:io';

import 'package:postgres/postgres.dart';

PostgreSQLConnection createPostgreSqlConnection(String connectionUri) {
  final uri = Uri.parse(connectionUri);
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'postgres' && scheme != 'postgresql') {
    throw ArgumentError(
      'Unsupported database scheme "$scheme". Use postgres:// or postgresql://',
    );
  }

  final databaseName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  if (databaseName.isEmpty) {
    throw ArgumentError(
      'Database name missing in connection URI: $connectionUri',
    );
  }

  final userInfo = uri.userInfo.split(':');
  final username = userInfo.isNotEmpty && userInfo.first.isNotEmpty
      ? Uri.decodeComponent(userInfo.first)
      : null;
  final password = userInfo.length > 1 && userInfo[1].isNotEmpty
      ? Uri.decodeComponent(userInfo[1])
      : null;

  final sslMode = uri.queryParameters['sslmode']?.toLowerCase();
  final useSSL =
      sslMode != null &&
      sslMode != 'disable' &&
      sslMode != 'allow' &&
      sslMode != 'prefer';

  return PostgreSQLConnection(
    uri.host.isEmpty ? 'localhost' : uri.host,
    uri.hasPort ? uri.port : 5432,
    databaseName,
    username: username,
    password: password,
    useSSL: useSSL,
    timeZone: 'UTC',
  );
}

Future<PostgreSQLConnection> openPostgreSqlConnection(
  String connectionUri,
) async {
  final connection = createPostgreSqlConnection(connectionUri);
  await connection.open();
  return connection;
}

PostgreSQLConnection createPostgreSqlConnectionFromEnv({
  Map<String, String>? env,
}) {
  final source = env ?? Platform.environment;
  final host = source['PGHOST']?.trim();
  final portRaw = source['PGPORT']?.trim();
  final database = source['PGDATABASE']?.trim();
  final username = source['PGUSER']?.trim();
  final password = source['PGPASSWORD']?.trim();

  if (host == null || host.isEmpty) {
    throw ArgumentError('Missing PGHOST');
  }
  if (database == null || database.isEmpty) {
    throw ArgumentError('Missing PGDATABASE');
  }
  if (username == null || username.isEmpty) {
    throw ArgumentError('Missing PGUSER');
  }
  if (password == null || password.isEmpty) {
    throw ArgumentError('Missing PGPASSWORD');
  }

  final port = int.tryParse(portRaw ?? '');
  if (port == null) {
    throw ArgumentError('Invalid or missing PGPORT');
  }

  return PostgreSQLConnection(
    host,
    port,
    database,
    username: username,
    password: password,
    timeZone: 'UTC',
  );
}

Future<PostgreSQLConnection> openPostgreSqlConnectionFromEnv({
  Map<String, String>? env,
}) async {
  final connection = createPostgreSqlConnectionFromEnv(env: env);
  await connection.open();
  return connection;
}

Future<List<PostgreSQLResultRow>> runPostgreSqlQuery({
  required PostgreSQLConnection connection,
  required String sql,
  Map<String, dynamic>? params,
}) {
  return connection.query(sql, substitutionValues: params);
}
