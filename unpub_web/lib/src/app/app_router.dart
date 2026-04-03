import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/pages/admin_tokens_page.dart';
import '../features/admin/presentation/pages/login_page.dart';
import '../features/packages/presentation/pages/package_detail_page.dart';
import '../features/packages/presentation/pages/package_list_page.dart';
import '../l10n/app_localizations_ext.dart';
import 'app_dependencies.dart';
import '../shared/widgets/app_scaffold.dart';

GoRouter createAppRouter(AppDependencies dependencies) {
  return GoRouter(
    refreshListenable: dependencies.authSession,
    redirect: (context, state) {
      final path = state.uri.path;
      final isAdminPath = path.startsWith('/admin');
      final isLoginPath = path == '/login';

      if (isAdminPath && !dependencies.authSession.isLoggedIn) {
        return '/login?from=${Uri.encodeQueryComponent(state.uri.toString())}';
      }
      if (isLoginPath && dependencies.authSession.isLoggedIn) {
        return '/admin/tokens';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final query = state.uri.queryParameters['q'];
          final page = int.tryParse(state.uri.queryParameters['page'] ?? '0') ?? 0;
          return PackageListPage(
            authSession: dependencies.authSession,
            packagesRepository: dependencies.packagesRepository,
            page: page,
            searchQuery: query,
            size: 15,
          );
        },
      ),
      GoRoute(
        path: '/packages',
        builder: (context, state) {
          final query = state.uri.queryParameters['q'];
          final page = int.tryParse(state.uri.queryParameters['page'] ?? '0') ?? 0;
          return PackageListPage(
            authSession: dependencies.authSession,
            packagesRepository: dependencies.packagesRepository,
            page: page,
            searchQuery: query,
            size: 15,
          );
        },
      ),
      GoRoute(
        path: '/packages/:name',
        builder: (context, state) {
          return PackageDetailPage(
            authSession: dependencies.authSession,
            packagesRepository: dependencies.packagesRepository,
            name: Uri.decodeComponent(state.pathParameters['name']!),
            version: 'latest',
          );
        },
      ),
      GoRoute(
        path: '/packages/:name/versions/:version',
        builder: (context, state) {
          return PackageDetailPage(
            authSession: dependencies.authSession,
            packagesRepository: dependencies.packagesRepository,
            name: Uri.decodeComponent(state.pathParameters['name']!),
            version: Uri.decodeComponent(state.pathParameters['version']!),
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return LoginPage(
            authSession: dependencies.authSession,
            from: state.uri.queryParameters['from'],
          );
        },
      ),
      GoRoute(
        path: '/admin/tokens',
        builder: (context, state) {
          return AdminTokensPage(
            authSession: dependencies.authSession,
            adminRepository: dependencies.adminRepository,
          );
        },
      ),
    ],
    errorBuilder: (context, state) {
      final l10n = context.l10n;
      return AppScaffold(
        authSession: dependencies.authSession,
        searchQuery: null,
        onSearch: (value) {
          final query = value.trim();
          if (query.isEmpty) {
            context.go('/packages');
            return;
          }
          context.go('/packages?q=${Uri.encodeQueryComponent(query)}');
        },
        body: Center(child: Text(l10n.notFound)),
      );
    },
  );
}

