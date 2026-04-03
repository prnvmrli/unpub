import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:unpub_web/l10n/app_localizations.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../l10n/app_localizations_ext.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../data/admin_repository.dart';
import '../bloc/admin_tokens_cubit.dart';

class AdminTokensPage extends StatelessWidget {
  const AdminTokensPage({
    required this.authSession,
    required this.adminRepository,
    super.key,
  });

  final AuthSession authSession;
  final AdminRepository adminRepository;

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
      create: (_) => AdminTokensCubit(
        adminRepository: adminRepository,
        authSession: authSession,
      )..load(),
      child: AppScaffold(
        authSession: authSession,
        searchQuery: null,
        onSearch: (value) => _search(context, value),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: BlocBuilder<AdminTokensCubit, AdminTokensState>(
              builder: (context, state) {
                final cubit = context.read<AdminTokensCubit>();
                final feedback = state.errorMessage ?? _noticeText(l10n, state.notice);
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.adminDashboard,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            authSession.logout();
                            context.go('/login');
                          },
                          child: Text(l10n.logout),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.sessionToken(authSession.shortToken)),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Checkbox(
                              value: state.includeAll,
                              onChanged: (value) => cubit.setIncludeAll(value ?? false),
                            ),
                            Text(l10n.includeAllAdminOnly),
                            const Spacer(),
                            FilledButton(
                              onPressed: state.loading ? null : cubit.load,
                              child: Text(l10n.refresh),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.createToken,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: cubit.setOwnerName,
                              decoration: InputDecoration(
                                labelText: l10n.ownerNameOptional,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: cubit.setExpiresAt,
                              decoration: InputDecoration(
                                labelText: l10n.expiresAtOptional,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: state.loading ? null : cubit.createToken,
                              child: Text(l10n.createTokenCta),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      duration: const Duration(milliseconds: 420),
                      child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.revokeToken,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: cubit.setRevokeTokenId,
                              decoration: InputDecoration(
                                labelText: l10n.tokenId,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonal(
                              onPressed: state.loading ? null : cubit.revokeToken,
                              child: Text(l10n.revoke),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    if (feedback != null) ...[
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          feedback,
                          key: ValueKey(feedback),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      l10n.tokensHeading(state.tokens.length),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(l10n.id)),
                            DataColumn(label: Text(l10n.owner)),
                            DataColumn(label: Text(l10n.status)),
                            DataColumn(label: Text(l10n.createdAt)),
                            DataColumn(label: Text(l10n.expiresAt)),
                            DataColumn(label: Text(l10n.lastUsedAt)),
                            DataColumn(label: Text(l10n.token)),
                          ],
                          rows: [
                            for (final token in state.tokens)
                              DataRow(
                                cells: [
                                  DataCell(Text('${token.id}')),
                                  DataCell(Text(token.ownerName)),
                                  DataCell(Text(token.status)),
                                  DataCell(Text(token.createdAt ?? '')),
                                  DataCell(Text(token.expiresAt ?? '')),
                                  DataCell(Text(token.lastUsedAt ?? '')),
                                  DataCell(SelectableText(token.token)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.downloadLogsHeading(state.downloads.length),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(l10n.id)),
                            DataColumn(label: Text(l10n.token)),
                            DataColumn(label: Text(l10n.package)),
                            DataColumn(label: Text(l10n.version)),
                            DataColumn(label: Text(l10n.timestamp)),
                            DataColumn(label: Text(l10n.ip)),
                          ],
                          rows: [
                            for (final download in state.downloads)
                              DataRow(
                                cells: [
                                  DataCell(Text('${download.id}')),
                                  DataCell(Text(download.token)),
                                  DataCell(Text(download.packageName)),
                                  DataCell(Text(download.version)),
                                  DataCell(Text(download.timestamp)),
                                  DataCell(Text(download.ipAddress ?? '')),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String? _noticeText(AppLocalizations l10n, AdminNotice? notice) {
    if (notice == null) return null;
    switch (notice.type) {
      case AdminNoticeType.tokenCreated:
        return l10n.tokenCreated(notice.value ?? '');
      case AdminNoticeType.tokenRevoked:
        return l10n.tokenRevoked(notice.value ?? '');
      case AdminNoticeType.missingTokenId:
        return l10n.enterTokenIdToRevoke;
    }
  }
}
