import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../l10n/app_localizations_ext.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../data/packages_repository.dart';
import '../bloc/package_list_cubit.dart';

class PackageListPage extends StatelessWidget {
  const PackageListPage({
    required this.authSession,
    required this.packagesRepository,
    required this.page,
    required this.searchQuery,
    this.size = 15,
    super.key,
  });

  final AuthSession authSession;
  final PackagesRepository packagesRepository;
  final int size;
  final int page;
  final String? searchQuery;

  void _search(BuildContext context, String value) {
    final query = value.trim();
    if (query.isEmpty) {
      context.go('/packages');
      return;
    }
    context.go('/packages?q=${Uri.encodeQueryComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider(
      key: ValueKey('list-$page-${searchQuery ?? ''}'),
      create: (_) => PackageListCubit(packagesRepository)
        ..load(
          size: size,
          page: page,
          searchQuery: searchQuery,
        ),
      child: AppScaffold(
        authSession: authSession,
        searchQuery: searchQuery,
        onSearch: (value) => _search(context, value),
        body: BlocBuilder<PackageListCubit, PackageListState>(
          builder: (context, state) {
            Widget content;

            if (state is PackageListError) {
              content = Center(child: Text(state.message));
            } else if (state is! PackageListLoaded) {
              content = const Center(child: CircularProgressIndicator());
            } else {
              final data = state.data;
              final pageCount = (data.count / size).ceil();

              content = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          searchQuery == null || searchQuery!.isEmpty
                              ? l10n.privatePackages
                              : l10n.searchResultsFor(searchQuery!),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Text(
                            l10n.packageCount(data.count),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.separated(
                            itemCount: data.packages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final package = data.packages[index];
                              return FadeSlideIn(
                                key: ValueKey(package.name),
                                duration: Duration(milliseconds: 220 + (index * 30)),
                                child: Card(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => context.go('/packages/${Uri.encodeComponent(package.name)}'),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF0059A8), Color(0xFF14A2E2)],
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.inventory_2_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  package.name,
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  package.description ?? l10n.noDescription,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 220),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: scheme.secondaryContainer,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              package.latest,
                                              style: TextStyle(color: scheme.onSecondaryContainer),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (pageCount > 1)
                          Wrap(
                            spacing: 8,
                            children: [
                              for (var index = 0; index < pageCount; index++)
                                FilledButton.tonal(
                                  onPressed: index == page
                                      ? null
                                      : () {
                                          final query = searchQuery?.trim();
                                          final params = <String, String>{};
                                          if (query != null && query.isNotEmpty) params['q'] = query;
                                          if (index > 0) params['page'] = '$index';
                                          final uri = Uri(
                                            path: '/packages',
                                            queryParameters: params.isEmpty ? null : params,
                                          );
                                          context.go(uri.toString());
                                        },
                                  child: Text('${index + 1}'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey(state.runtimeType),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}
