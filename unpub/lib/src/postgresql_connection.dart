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
