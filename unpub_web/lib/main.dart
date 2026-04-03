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
      title: 'unpub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0175C2),
          secondary: Color(0xFF13B9FD),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
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
      return PackageListPage(
        title: 'Private packages',
        searchQuery: uri.queryParameters['q'],
        page: int.tryParse(uri.queryParameters['page'] ?? '0') ?? 0,
        size: 15,
      );
    }

    if (segments.length == 1 && segments[0] == 'packages') {
      return PackageListPage(
        title: 'Packages',
        searchQuery: uri.queryParameters['q'],
        page: int.tryParse(uri.queryParameters['page'] ?? '0') ?? 0,
      );
    }

    if (segments.length == 2 && segments[0] == 'packages') {
      return PackageDetailPage(
        name: Uri.decodeComponent(segments[1]),
        version: 'latest',
      );
    }

    if (segments.length == 4 &&
        segments[0] == 'packages' &&
        segments[2] == 'versions') {
      return PackageDetailPage(
        name: Uri.decodeComponent(segments[1]),
        version: Uri.decodeComponent(segments[3]),
      );
    }

    return _PubScaffold(
      searchQuery: null,
      onSearch: (_) {},
      body: const Center(child: Text('Not found')),
    );
  }
}

class _PubScaffold extends StatelessWidget {
  final String? searchQuery;
  final ValueChanged<String> onSearch;
  final Widget body;

  const _PubScaffold({
    required this.searchQuery,
    required this.onSearch,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _TopHeader(searchQuery: searchQuery, onSearch: onSearch),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _TopHeader extends StatefulWidget {
  final String? searchQuery;
  final ValueChanged<String> onSearch;

  const _TopHeader({required this.searchQuery, required this.onSearch});

  @override
  State<_TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<_TopHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery ?? '');
  }

  @override
  void didUpdateWidget(covariant _TopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _controller.text != (widget.searchQuery ?? '')) {
      _controller.text = widget.searchQuery ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 860;
    final title = GestureDetector(
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              const PackageListPage(title: 'Private packages', size: 15),
          settings: const RouteSettings(name: '/'),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.bubble_chart_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'pub.dev',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    final search = TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: widget.onSearch,
      decoration: InputDecoration(
        hintText: 'Search packages',
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        fillColor: Colors.white,
        filled: true,
      ),
    );

    return Container(
      color: const Color(0xFF0059A8),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 12), search],
                    )
                  : Row(
                      children: [
                        title,
                        const SizedBox(width: 24),
                        Expanded(child: search),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class PackageListPage extends StatefulWidget {
  final String title;
  final int size;
  final int page;
  final String? searchQuery;

  const PackageListPage({
    required this.title,
    this.size = 10,
    this.page = 0,
    this.searchQuery,
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
    _future = _Api.fetchPackages(
      size: widget.size,
      page: widget.page,
      q: widget.searchQuery,
    );
  }

  void _openSearch(String value) {
    final query = value.trim();
    final queryParameters = <String, String>{};
    if (query.isNotEmpty) {
      queryParameters['q'] = query;
    }

    final uri = Uri(
      path: '/packages',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PackageListPage(
          title: 'Packages',
          searchQuery: query.isEmpty ? null : query,
          page: 0,
          size: widget.size,
        ),
        settings: RouteSettings(name: uri.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PubScaffold(
      searchQuery: widget.searchQuery,
      onSearch: _openSearch,
      body: FutureBuilder<ListApi>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredCard(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final pageCount = (data.count / widget.size).ceil();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.searchQuery == null || widget.searchQuery!.isEmpty
                          ? 'Private packages'
                          : 'Search results for "${widget.searchQuery}"',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${data.count} package${data.count == 1 ? '' : 's'}',
                      style: const TextStyle(color: Color(0xFF516173)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: data.packages.isEmpty
                          ? _CenteredCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No packages found',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Try a different search term.'),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: data.packages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) => _PackageListItem(
                                package: data.packages[index],
                                onTap: () {
                                  final pkg = data.packages[index];
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PackageDetailPage(
                                        name: pkg.name,
                                        version: 'latest',
                                      ),
                                      settings: RouteSettings(
                                        name:
                                            '/packages/${Uri.encodeComponent(pkg.name)}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    if (pageCount > 1)
                      _PaginationBar(
                        pageCount: pageCount,
                        currentPage: widget.page,
                        onSelect: (index) {
                          final params = <String, String>{};
                          final q = widget.searchQuery?.trim();
                          if (q != null && q.isNotEmpty) {
                            params['q'] = q;
                          }
                          if (index > 0) {
                            params['page'] = '$index';
                          }

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => PackageListPage(
                                title: widget.title,
                                size: widget.size,
                                page: index,
                                searchQuery: q,
                              ),
                              settings: RouteSettings(
                                name: Uri(
                                  path: '/packages',
                                  queryParameters: params.isEmpty
                                      ? null
                                      : params,
                                ).toString(),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PackageListItem extends StatelessWidget {
  final ListApiPackage package;
  final VoidCallback onTap;

  const _PackageListItem({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      package.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF02569B),
                      ),
                    ),
                  ),
                  _ChipLabel(label: package.latest),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                package.description?.trim().isNotEmpty == true
                    ? package.description!.trim()
                    : 'No package description provided.',
                style: const TextStyle(color: Color(0xFF2D3A49), height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _MetaText('Updated ${_relativeTime(package.updatedAt)}'),
                  if (package.tags.isNotEmpty)
                    _MetaText(package.tags.whereType<String>().join(' • ')),
                ],
              ),
            ],
          ),
        ),
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

enum _DetailTab { readme, changelog, versions, dependencies }

class _PackageDetailPageState extends State<PackageDetailPage> {
  late Future<WebapiDetailView> _future;
  _DetailTab _tab = _DetailTab.readme;

  @override
  void initState() {
    super.initState();
    _future = _Api.fetchPackage(widget.name, widget.version);
  }

  void _openSearch(String value) {
    final query = value.trim();
    final params = <String, String>{};
    if (query.isNotEmpty) {
      params['q'] = query;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PackageListPage(
          title: 'Packages',
          searchQuery: query.isEmpty ? null : query,
          page: 0,
        ),
        settings: RouteSettings(
          name: Uri(
            path: '/packages',
            queryParameters: params.isEmpty ? null : params,
          ).toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PubScaffold(
      searchQuery: null,
      onSearch: _openSearch,
      body: FutureBuilder<WebapiDetailView>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredCard(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final isNarrow = MediaQuery.sizeOf(context).width < 980;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: SingleChildScrollView(
                  child: isNarrow
                      ? Column(
                          children: [
                            _PackageHeadline(data: data),
                            const SizedBox(height: 16),
                            _DetailTabs(
                              selected: _tab,
                              onSelect: (tab) => setState(() => _tab = tab),
                            ),
                            const SizedBox(height: 12),
                            _DetailMainPanel(data: data, selectedTab: _tab),
                            const SizedBox(height: 16),
                            _DetailSidePanel(data: data),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 68,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _PackageHeadline(data: data),
                                  const SizedBox(height: 16),
                                  _DetailTabs(
                                    selected: _tab,
                                    onSelect: (tab) =>
                                        setState(() => _tab = tab),
                                  ),
                                  const SizedBox(height: 12),
                                  _DetailMainPanel(
                                    data: data,
                                    selectedTab: _tab,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 320,
                              child: _DetailSidePanel(data: data),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PackageHeadline extends StatelessWidget {
  final WebapiDetailView data;

  const _PackageHeadline({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    data.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF02569B),
                    ),
                  ),
                ),
                _ChipLabel(label: data.version),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.description.trim().isEmpty
                  ? 'No description provided.'
                  : data.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Color(0xFF263342),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  final _DetailTab selected;
  final ValueChanged<_DetailTab> onSelect;

  const _DetailTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _DetailTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected == tab,
                onSelected: (_) => onSelect(tab),
                label: Text(_tabTitle(tab)),
              ),
            ),
        ],
      ),
    );
  }

  String _tabTitle(_DetailTab tab) {
    switch (tab) {
      case _DetailTab.readme:
        return 'Readme';
      case _DetailTab.changelog:
        return 'Changelog';
      case _DetailTab.versions:
        return 'Versions';
      case _DetailTab.dependencies:
        return 'Dependencies';
    }
  }
}

class _DetailMainPanel extends StatelessWidget {
  final WebapiDetailView data;
  final _DetailTab selectedTab;

  const _DetailMainPanel({required this.data, required this.selectedTab});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (selectedTab) {
      case _DetailTab.readme:
        return _LongTextContent(
          title: 'README',
          body: data.readme?.trim().isNotEmpty == true
              ? data.readme!
              : 'No README has been published for this package.',
        );
      case _DetailTab.changelog:
        return _LongTextContent(
          title: 'CHANGELOG',
          body: data.changelog?.trim().isNotEmpty == true
              ? data.changelog!
              : 'No changelog has been published for this package.',
        );
      case _DetailTab.versions:
        if (data.versions.isEmpty) {
          return const Text('No versions available.');
        }
        return Column(
          children: [
            for (var index = 0; index < data.versions.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  data.versions[index].version,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Published ${_relativeTime(data.versions[index].createdAt)}',
                ),
                trailing: TextButton(
                  onPressed: () {
                    final version = data.versions[index].version;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PackageDetailPage(
                          name: data.name,
                          version: version,
                        ),
                        settings: RouteSettings(
                          name:
                              '/packages/${Uri.encodeComponent(data.name)}/versions/${Uri.encodeComponent(version)}',
                        ),
                      ),
                    );
                  },
                  child: const Text('View'),
                ),
              ),
            ],
          ],
        );
      case _DetailTab.dependencies:
        final deps =
            data.dependencies?.whereType<String>().toList() ?? const <String>[];
        if (deps.isEmpty) {
          return const Text('No dependencies listed.');
        }
        return Column(
          children: [
            for (var index = 0; index < deps.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(deps[index]),
                leading: const Icon(Icons.circle, size: 10),
              ),
          ],
        );
    }
  }
}

class _LongTextContent extends StatelessWidget {
  final String title;
  final String body;

  const _LongTextContent({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SingleChildScrollView(
          child: SelectableText(
            body,
            style: const TextStyle(fontFamily: 'monospace', height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _DetailSidePanel extends StatelessWidget {
  final WebapiDetailView data;

  const _DetailSidePanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Metadata',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _MetaBlock(
              label: 'Published',
              value: _relativeDate(data.createdAt),
            ),
            _MetaBlock(label: 'Latest version', value: data.version),
            _MetaBlock(
              label: 'Homepage',
              value: data.homepage.trim().isNotEmpty
                  ? data.homepage
                  : 'Not provided',
            ),
            _MetaBlock(
              label: 'Uploaders',
              value: data.uploaders.isEmpty
                  ? 'Not provided'
                  : data.uploaders.join(', '),
            ),
            _MetaBlock(
              label: 'Authors',
              value: data.authors.whereType<String>().isEmpty
                  ? 'Not provided'
                  : data.authors.whereType<String>().join(', '),
            ),
            if (data.tags.isNotEmpty)
              _MetaBlock(label: 'Tags', value: data.tags.join(', ')),
          ],
        ),
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  final String label;
  final String value;

  const _MetaBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E5E70),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(color: Color(0xFF1E2B3A)),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final ValueChanged<int> onSelect;

  const _PaginationBar({
    required this.pageCount,
    required this.currentPage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < pageCount; i++)
            FilledButton.tonal(
              onPressed: i == currentPage ? null : () => onSelect(i),
              child: Text('${i + 1}'),
            ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;

  const _ChipLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF02569B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String text;

  const _MetaText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF58697C), fontSize: 13),
    );
  }
}

class _CenteredCard extends StatelessWidget {
  final Widget child;

  const _CenteredCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final delta = now.difference(value);

  if (delta.inSeconds < 60) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 30) return '${delta.inDays}d ago';
  if (delta.inDays < 365) return '${(delta.inDays / 30).floor()}mo ago';
  return '${(delta.inDays / 365).floor()}y ago';
}

String _relativeDate(DateTime value) {
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
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
    final data = await _fetch(
      '/webapi/packages',
      queryParameters: {'size': size, 'page': page, 'q': q},
    );
    return ListApi.fromJson(data);
  }

  static Future<WebapiDetailView> fetchPackage(
    String name,
    String version,
  ) async {
    final data = await _fetch('/webapi/package/$name/$version');
    return WebapiDetailView.fromJson(data);
  }
}
