// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $homeRoute,
  $packagesRoute,
  $packageLatestRoute,
  $packageVersionRoute,
  $loginRoute,
  $dashboardRoute,
  $adminTokensLegacyRoute,
];

RouteBase get $homeRoute =>
    GoRouteData.$route(path: '/', factory: $HomeRoute._fromState);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => HomeRoute(
    q: state.uri.queryParameters['q'],
    page: _$convertMapValue('page', state.uri.queryParameters, int.tryParse),
  );

  HomeRoute get _self => this as HomeRoute;

  @override
  String get location => GoRouteData.$location(
    '/',
    queryParams: {
      if (_self.q != null) 'q': _self.q,
      if (_self.page != null) 'page': _self.page!.toString(),
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

RouteBase get $packagesRoute =>
    GoRouteData.$route(path: '/packages', factory: $PackagesRoute._fromState);

mixin $PackagesRoute on GoRouteData {
  static PackagesRoute _fromState(GoRouterState state) => PackagesRoute(
    q: state.uri.queryParameters['q'],
    page: _$convertMapValue('page', state.uri.queryParameters, int.tryParse),
  );

  PackagesRoute get _self => this as PackagesRoute;

  @override
  String get location => GoRouteData.$location(
    '/packages',
    queryParams: {
      if (_self.q != null) 'q': _self.q,
      if (_self.page != null) 'page': _self.page!.toString(),
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $packageLatestRoute => GoRouteData.$route(
  path: '/packages/:name',
  factory: $PackageLatestRoute._fromState,
);

mixin $PackageLatestRoute on GoRouteData {
  static PackageLatestRoute _fromState(GoRouterState state) =>
      PackageLatestRoute(name: state.pathParameters['name']!);

  PackageLatestRoute get _self => this as PackageLatestRoute;

  @override
  String get location =>
      GoRouteData.$location('/packages/${Uri.encodeComponent(_self.name)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $packageVersionRoute => GoRouteData.$route(
  path: '/packages/:name/versions/:version',
  factory: $PackageVersionRoute._fromState,
);

mixin $PackageVersionRoute on GoRouteData {
  static PackageVersionRoute _fromState(GoRouterState state) =>
      PackageVersionRoute(
        name: state.pathParameters['name']!,
        version: state.pathParameters['version']!,
      );

  PackageVersionRoute get _self => this as PackageVersionRoute;

  @override
  String get location => GoRouteData.$location(
    '/packages/${Uri.encodeComponent(_self.name)}/versions/${Uri.encodeComponent(_self.version)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $loginRoute =>
    GoRouteData.$route(path: '/login', factory: $LoginRoute._fromState);

mixin $LoginRoute on GoRouteData {
  static LoginRoute _fromState(GoRouterState state) =>
      LoginRoute(from: state.uri.queryParameters['from']);

  LoginRoute get _self => this as LoginRoute;

  @override
  String get location => GoRouteData.$location(
    '/login',
    queryParams: {if (_self.from != null) 'from': _self.from},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $dashboardRoute =>
    GoRouteData.$route(path: '/dashboard', factory: $DashboardRoute._fromState);

mixin $DashboardRoute on GoRouteData {
  static DashboardRoute _fromState(GoRouterState state) =>
      const DashboardRoute();

  @override
  String get location => GoRouteData.$location('/dashboard');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $adminTokensLegacyRoute => GoRouteData.$route(
  path: '/admin/tokens',
  factory: $AdminTokensLegacyRoute._fromState,
);

mixin $AdminTokensLegacyRoute on GoRouteData {
  static AdminTokensLegacyRoute _fromState(GoRouterState state) =>
      const AdminTokensLegacyRoute();

  @override
  String get location => GoRouteData.$location('/admin/tokens');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
