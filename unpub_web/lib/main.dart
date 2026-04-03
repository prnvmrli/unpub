import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:unpub_api/models.dart';

void main() {
  runApp(const UnpubApp());
}

class UnpubApp extends StatelessWidget {
  const UnpubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unpub',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const RoutePage(),
    );
  }
}

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      return const PackageListPage(title: 'Private Packages', size: 15);
    }

    if (segments.length == 1 && segments[0] == 'packages') {
      final q = uri.queryParameters['q'];
      final page = int.tryParse(uri.queryParameters['page'] ?? '0') ?? 0;
      return PackageListPage(title: q == null ? 'Packages' : 'Search: $q', query: q, page: page);
    }

    if (segments.length == 2 && segments[0] == 'packages') {
      return PackageDetailPage(name: Uri.decodeComponent(segments[1]), version: 'latest');
    }

    if (segments.length == 4 &&
        segments[0] == 'packages' &&
        segments[2] == 'versions') {
      return PackageDetailPage(
        name: Uri.decodeComponent(segments[1]),
        version: Uri.decodeComponent(segments[3]),
      );
    }

    return const Scaffold(
      body: Center(child: Text('Not found')),
    );
  }
}

class PackageListPage extends StatefulWidget {
  final String title;
  final int size;
  final int page;
  final String? query;

  const PackageListPage({
    required this.title,
    this.size = 10,
    this.page = 0,
    this.query,
    super.key,
  });

  @override
  State<PackageListPage> createState() => _PackageListPageState();
}

class _PackageListPageState extends State<PackageListPage> {
  late Future<ListApi> _future;

  @override
  void initState() {
    super.initState();
    _future = _Api.fetchPackages(size: widget.size, page: widget.page, q: widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<ListApi>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final pageCount = (data.count / widget.size).ceil();
          final isEmpty = data.packages.isEmpty;

          if (isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.query == null || widget.query!.isEmpty
                                ? 'No packages yet'
                                : 'No matching packages',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.query == null || widget.query!.isEmpty
                                ? 'This registry does not have any published packages yet.'
                                : 'Try a different search term or clear the search query.',
                          ),
                          if (widget.query == null || widget.query!.isEmpty) ...[
                            const SizedBox(height: 12),
                            const SelectableText(
                              'To publish your first package, run:\n'
                              'dart pub publish --server http://localhost:4000',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: data.packages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final pkg = data.packages[index];
                    return ListTile(
                      title: Text('${pkg.name} ${pkg.latest}'),
                      subtitle: pkg.description == null ? null : Text(pkg.description!),
                      onTap: () {
                        final target = '/packages/${Uri.encodeComponent(pkg.name)}';
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PackageDetailPage(name: pkg.name, version: 'latest'),
                            settings: RouteSettings(name: target),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (pageCount > 1)
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pageCount,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: OutlinedButton(
                          onPressed: index == widget.page
                              ? null
                              : () {
                                  final query = <String, String>{};
                                  if (widget.query != null && widget.query!.isNotEmpty) {
                                    query['q'] = widget.query!;
                                  }
                                  if (index > 0) {
                                    query['page'] = '$index';
                                  }
                                  final uri = Uri(path: '/packages', queryParameters: query.isEmpty ? null : query);
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PackageListPage(
                                        title: widget.query == null ? 'Packages' : 'Search: ${widget.query}',
                                        size: widget.size,
                                        page: index,
                                        query: widget.query,
                                      ),
                                      settings: RouteSettings(name: uri.toString()),
                                    ),
                                  );
                                },
                          child: Text('${index + 1}'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PackageDetailPage extends StatefulWidget {
  final String name;
  final String version;

  const PackageDetailPage({
    required this.name,
    required this.version,
    super.key,
  });

  @override
  State<PackageDetailPage> createState() => _PackageDetailPageState();
}

class _PackageDetailPageState extends State<PackageDetailPage> {
  late Future<WebapiDetailView> _future;

  @override
  void initState() {
    super.initState();
    _future = _Api.fetchPackage(widget.name, widget.version);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<WebapiDetailView>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${data.name} ${data.version}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(data.description),
              if (data.homepage.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(data.homepage),
              ],
              const SizedBox(height: 16),
              Text('Versions', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: [
                  for (final v in data.versions)
                    ActionChip(
                      label: Text(v.version),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => PackageDetailPage(name: data.name, version: v.version),
                            settings: RouteSettings(
                              name:
                                  '/packages/${Uri.encodeComponent(data.name)}/versions/${Uri.encodeComponent(v.version)}',
                            ),
                          ),
                        );
                      },
                    )
                ],
              ),
              if ((data.dependencies ?? const <String>[]).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Dependencies', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final dep in data.dependencies!) Text('- $dep'),
              ],
              if (data.readme != null && data.readme!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('README', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(data.readme!),
              ],
              if (data.changelog != null && data.changelog!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('CHANGELOG', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(data.changelog!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Api {
  static Future<Map<String, dynamic>> _fetch(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final qp = <String, String>{};
    queryParameters?.forEach((key, value) {
      if (value != null) {
        qp[key] = value.toString();
      }
    });

    final uri = Uri(path: path, queryParameters: qp.isEmpty ? null : qp);
    final res = await http.get(uri);
    if (res.statusCode >= 400) {
      throw 'Request failed (${res.statusCode})';
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw body['error'].toString();
    }
    return body['data'] as Map<String, dynamic>;
  }

  static Future<ListApi> fetchPackages({
    int? size,
    int? page,
    String? q,
  }) async {
    final data = await _fetch('/webapi/packages', queryParameters: {
      'size': size,
      'page': page,
      'q': q,
    });
    return ListApi.fromJson(data);
  }

  static Future<WebapiDetailView> fetchPackage(String name, String version) async {
    final data = await _fetch('/webapi/package/$name/$version');
    return WebapiDetailView.fromJson(data);
  }
}
