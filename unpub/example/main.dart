import 'package:unpub/unpub.dart' as unpub;

main(List<String> args) async {
  final db = await unpub.openPostgreSqlConnection(
    'postgresql://localhost:5432/dart_pub?sslmode=disable',
  );

  final app = unpub.App(
    metaStore: unpub.PostgreSqlMetaStore(db),
    packageStore: unpub.FileStore('./unpub-packages'),
  );

  final server = await app.serve('0.0.0.0', 4000);
  print('Serving at http://${server.address.host}:${server.port}');
}
