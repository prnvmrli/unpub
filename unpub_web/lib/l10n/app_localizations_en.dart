// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'unpub';

  @override
  String get notFound => 'Not found';

  @override
  String get searchPackages => 'Search packages';

  @override
  String get admin => 'Admin';

  @override
  String get login => 'Login';

  @override
  String get switchToDark => 'Switch to dark mode';

  @override
  String get switchToLight => 'Switch to light mode';

  @override
  String get privatePackages => 'Private packages';

  @override
  String searchResultsFor(Object query) {
    return 'Search results for \"$query\"';
  }

  @override
  String packageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packages',
      one: '1 package',
    );
    return '$_temp0';
  }

  @override
  String get noDescription => 'No description';

  @override
  String get versions => 'Versions';

  @override
  String get pasteBearerToken => 'Paste bearer token for admin APIs.';

  @override
  String get bearerToken => 'Bearer token';

  @override
  String get enterBearerToken => 'Enter bearer token';

  @override
  String get invalidTokenUnauthorized => 'Invalid token or unauthorized';

  @override
  String get validating => 'Validating...';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get logout => 'Logout';

  @override
  String sessionToken(Object token) {
    return 'Session: $token';
  }

  @override
  String get includeAllAdminOnly => 'Include all (admin only)';

  @override
  String get refresh => 'Refresh';

  @override
  String get createToken => 'Create Token';

  @override
  String get ownerNameOptional => 'owner_name (optional)';

  @override
  String get expiresAtOptional => 'expires_at (ISO-8601, optional)';

  @override
  String get createTokenCta => 'Create token';

  @override
  String get revokeToken => 'Revoke Token';

  @override
  String get tokenId => 'Token id';

  @override
  String get revoke => 'Revoke';

  @override
  String tokensHeading(int count) {
    return 'Tokens ($count)';
  }

  @override
  String downloadLogsHeading(int count) {
    return 'Download Logs ($count)';
  }

  @override
  String tokenCreated(Object token) {
    return 'Token created: $token';
  }

  @override
  String tokenRevoked(Object tokenId) {
    return 'Token revoked: $tokenId';
  }

  @override
  String get enterTokenIdToRevoke => 'Enter token id to revoke';

  @override
  String get id => 'id';

  @override
  String get owner => 'owner';

  @override
  String get status => 'status';

  @override
  String get createdAt => 'created_at';

  @override
  String get expiresAt => 'expires_at';

  @override
  String get lastUsedAt => 'last_used_at';

  @override
  String get token => 'token';

  @override
  String get package => 'package';

  @override
  String get version => 'version';

  @override
  String get timestamp => 'timestamp';

  @override
  String get ip => 'ip';
}
