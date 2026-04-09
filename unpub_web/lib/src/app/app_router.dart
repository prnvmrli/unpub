import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/pages/admin_tokens_page.dart';
import '../features/admin/presentation/pages/login_page.dart';
import '../features/packages/presentation/pages/package_detail_page.dart';
import '../features/packages/presentation/pages/package_list_page.dart';
import '../l10n/app_localizations_ext.dart';
import '../shared/widgets/app_scaffold.dart';
import 'app_dependencies.dart';

part 'app_router.g.dart';

late final AppDependencies _dependencies;

GoRouter createAppRouter(AppDependencies dependencies) {
  _dependencies = dependencies;

  return GoRouter(
    refreshListenable: dependencies.authSession,
    redirect: (context, state) {
      final path = state.uri.path;
      final isDashboardPath = path.startsWith('/dashboard');
      final isAdminPath = path.startsWith('/admin');
      final isLoginPath = path == '/login';
      final isProtectedPath = isDashboardPath || isAdminPath;

      if (isProtectedPath && !dependencies.authSession.isLoggedIn) {
        return LoginRoute(from: state.uri.toString()).location;
      }
      if (isLoginPath && dependencies.authSession.isLoggedIn) {
        return const DashboardRoute().location;
      }
      return null;
    },
    routes: $appRoutes,
    errorBuilder: (context, state) {
      final l10n = context.l10n;
      return AppScaffold(
        authSession: dependencies.authSession,
        searchQuery: null,
        onSearch: (value) {
          final query = value.trim();
          if (query.isEmpty) {
            const PackagesRoute().go(context);
            return;
          }
          PackagesRoute(q: query).go(context);
        },
        body: Center(child: Text(l10n.notFound)),
      );
    },
  );
}

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute({this.q, this.page});

  final String? q;
  final int? page;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return PackageListPage(
      authSession: _dependencies.authSession,
      packagesRepository: _dependencies.packagesRepository,
      page: page ?? 0,
      searchQuery: q,
      size: 15,
    );
  }
}

@TypedGoRoute<PackagesRoute>(path: '/packages')
class PackagesRoute extends GoRouteData with $PackagesRoute {
  const PackagesRoute({this.q, this.page});

  final String? q;
  final int? page;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return PackageListPage(
      authSession: _dependencies.authSession,
      packagesRepository: _dependencies.packagesRepository,
      page: page ?? 0,
      searchQuery: q,
      size: 15,
    );
  }
}

@TypedGoRoute<PackageLatestRoute>(path: '/packages/:name')
class PackageLatestRoute extends GoRouteData with $PackageLatestRoute {
  const PackageLatestRoute({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return PackageDetailPage(
      authSession: _dependencies.authSession,
      packagesRepository: _dependencies.packagesRepository,
      name: name,
      version: 'latest',
    );
  }
}

@TypedGoRoute<PackageVersionRoute>(path: '/packages/:name/versions/:version')
class PackageVersionRoute extends GoRouteData with $PackageVersionRoute {
  const PackageVersionRoute({required this.name, required this.version});

  final String name;
  final String version;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return PackageDetailPage(
      authSession: _dependencies.authSession,
      packagesRepository: _dependencies.packagesRepository,
      name: name,
      version: version,
    );
  }
}

@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData with $LoginRoute {
  const LoginRoute({this.from});

  final String? from;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return LoginPage(authSession: _dependencies.authSession, from: from);
  }
}

@TypedGoRoute<DashboardRoute>(path: '/dashboard')
class DashboardRoute extends GoRouteData with $DashboardRoute {
  const DashboardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AdminTokensPage(
      authSession: _dependencies.authSession,
      adminRepository: _dependencies.adminRepository,
    );
  }
}

@TypedGoRoute<AdminTokensLegacyRoute>(path: '/admin/tokens')
class AdminTokensLegacyRoute extends GoRouteData with $AdminTokensLegacyRoute {
  const AdminTokensLegacyRoute();

  @override
  String? redirect(BuildContext context, GoRouterState state) {
    return const DashboardRoute().location;
  }
}
