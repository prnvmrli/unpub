import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
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
    final role = authSession.userRole ?? 'client';
    final showAdminSections = role == 'admin';
    return BlocProvider(
      create: (_) => AdminTokensCubit(adminRepository: adminRepository)..load(),
      child: BlocListener<AdminTokensCubit, AdminTokensState>(
        listenWhen: (previous, current) =>
            previous.createdToken != current.createdToken &&
            current.createdToken != null,
        listener: (context, state) async {
          final token = state.createdToken;
          if (token == null) return;
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Token Created'),
                content: SelectableText(token),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Copy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
          if (context.mounted) {
            context.read<AdminTokensCubit>().clearCreatedToken();
          }
        },
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
                  final feedback =
                      state.errorMessage ?? _noticeText(l10n, state.notice);
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
                            onPressed: () async {
                              await authSession.logout();
                              if (!context.mounted) return;
                              context.go('/login');
                            },
                            child: Text(l10n.logout),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.sessionToken(authSession.ownerName ?? 'unknown'),
                      ),
                      const SizedBox(height: 4),
                      Text('Role: $role'),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if (showAdminSections) ...[
                                Checkbox(
                                  value: state.includeAll,
                                  onChanged: (value) =>
                                      cubit.setIncludeAll(value ?? false),
                                ),
                                Text(l10n.includeAllAdminOnly),
                              ] else ...[
                                const Text('Tokens'),
                              ],
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  onChanged: cubit.setTokenName,
                                  decoration: const InputDecoration(
                                    labelText: 'Token name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  keyboardType: TextInputType.number,
                                  onChanged: cubit.setExpiryDays,
                                  decoration: const InputDecoration(
                                    labelText: 'Expiry (days)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CheckboxListTile(
                                        value: state.canDownload,
                                        onChanged: (value) => cubit
                                            .setCanDownload(value ?? false),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Download'),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                    ),
                                    Expanded(
                                      child: CheckboxListTile(
                                        value: state.canPublish,
                                        onChanged: (value) =>
                                            cubit.setCanPublish(value ?? false),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Publish'),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: state.loading
                                      ? null
                                      : cubit.createToken,
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
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
                                  onPressed: state.loading
                                      ? null
                                      : cubit.revokeToken,
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
                      if (showAdminSections) ...[
                        Text(
                          'Users (${state.users.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('id')),
                                DataColumn(label: Text('email')),
                                DataColumn(label: Text('role')),
                                DataColumn(label: Text('status')),
                                DataColumn(label: Text('action')),
                              ],
                              rows: [
                                for (final user in state.users)
                                  DataRow(
                                    cells: [
                                      DataCell(Text('${user.id}')),
                                      DataCell(Text(user.email)),
                                      DataCell(Text(user.role)),
                                      DataCell(Text(user.status)),
                                      DataCell(
                                        FilledButton.tonal(
                                          onPressed:
                                              state.loading || user.isDisabled
                                              ? null
                                              : () => cubit.disableUserById(
                                                  user.id,
                                                ),
                                          child: const Text('Disable'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                              const DataColumn(label: Text('name')),
                              DataColumn(label: Text(l10n.expiresAt)),
                              const DataColumn(label: Text('permissions')),
                              const DataColumn(label: Text('revoked')),
                              const DataColumn(label: Text('action')),
                            ],
                            rows: [
                              for (final token in state.tokens)
                                DataRow(
                                  cells: [
                                    DataCell(Text(token.name)),
                                    DataCell(Text(token.expiresAt ?? '')),
                                    DataCell(
                                      Text(
                                        [
                                          if (token.canDownload) 'download',
                                          if (token.canPublish) 'publish',
                                        ].join(', '),
                                      ),
                                    ),
                                    DataCell(
                                      Text(token.revoked ? 'yes' : 'no'),
                                    ),
                                    DataCell(
                                      FilledButton.tonal(
                                        onPressed:
                                            (state.loading || token.revoked)
                                            ? null
                                            : () => cubit.revokeTokenById(
                                                token.id,
                                              ),
                                        child: Text(l10n.revoke),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (showAdminSections) ...[
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
                    ],
                  );
                },
              ),
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
        return 'Token created';
      case AdminNoticeType.tokenRevoked:
        return l10n.tokenRevoked(notice.value ?? '');
      case AdminNoticeType.missingTokenId:
        return l10n.enterTokenIdToRevoke;
      case AdminNoticeType.userDisabled:
        return 'User disabled: ${notice.value ?? ''}';
    }
  }
}
