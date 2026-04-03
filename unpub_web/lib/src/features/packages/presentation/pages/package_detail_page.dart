import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../l10n/app_localizations_ext.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../data/packages_repository.dart';
import '../bloc/package_detail_cubit.dart';

class PackageDetailPage extends StatelessWidget {
  const PackageDetailPage({
    required this.authSession,
    required this.packagesRepository,
    required this.name,
    required this.version,
    super.key,
  });

  final AuthSession authSession;
  final PackagesRepository packagesRepository;
  final String name;
  final String version;

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
      key: ValueKey('detail-$name-$version'),
      create: (_) => PackageDetailCubit(packagesRepository)
        ..load(
          name: name,
          version: version,
        ),
      child: AppScaffold(
        authSession: authSession,
        searchQuery: null,
        onSearch: (value) => _search(context, value),
        body: BlocBuilder<PackageDetailCubit, PackageDetailState>(
          builder: (context, state) {
            Widget content;
            if (state is PackageDetailError) {
              content = Center(child: Text(state.message));
            } else if (state is! PackageDetailLoaded) {
              content = const Center(child: CircularProgressIndicator());
            } else {
              final package = state.data;
              content = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      FadeSlideIn(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0059A8), Color(0xFF14A2E2)],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.extension_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        package.name,
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        package.version,
                                        style: TextStyle(color: scheme.onSecondaryContainer),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(package.description),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.versions,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final version in package.versions)
                                      ActionChip(
                                        label: Text(version.version),
                                        onPressed: () => context.go(
                                          '/packages/${Uri.encodeComponent(package.name)}/versions/${Uri.encodeComponent(version.version)}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
