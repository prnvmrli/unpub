import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'unpub'**
  String get appTitle;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @searchPackages.
  ///
  /// In en, this message translates to:
  /// **'Search packages'**
  String get searchPackages;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @switchToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchToDark;

  /// No description provided for @switchToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchToLight;

  /// No description provided for @privatePackages.
  ///
  /// In en, this message translates to:
  /// **'Private packages'**
  String get privatePackages;

  /// No description provided for @searchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Search results for \"{query}\"'**
  String searchResultsFor(Object query);

  /// No description provided for @packageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 package} other{{count} packages}}'**
  String packageCount(int count);

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// No description provided for @versions.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get versions;

  /// No description provided for @pasteBearerToken.
  ///
  /// In en, this message translates to:
  /// **'Paste bearer token for admin APIs.'**
  String get pasteBearerToken;

  /// No description provided for @bearerToken.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get bearerToken;

  /// No description provided for @enterBearerToken.
  ///
  /// In en, this message translates to:
  /// **'Enter bearer token'**
  String get enterBearerToken;

  /// No description provided for @invalidTokenUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Invalid token or unauthorized'**
  String get invalidTokenUnauthorized;

  /// No description provided for @validating.
  ///
  /// In en, this message translates to:
  /// **'Validating...'**
  String get validating;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @sessionToken.
  ///
  /// In en, this message translates to:
  /// **'Session: {token}'**
  String sessionToken(Object token);

  /// No description provided for @includeAllAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Include all (admin only)'**
  String get includeAllAdminOnly;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @createToken.
  ///
  /// In en, this message translates to:
  /// **'Create Token'**
  String get createToken;

  /// No description provided for @ownerNameOptional.
  ///
  /// In en, this message translates to:
  /// **'owner_name (optional)'**
  String get ownerNameOptional;

  /// No description provided for @expiresAtOptional.
  ///
  /// In en, this message translates to:
  /// **'expires_at (ISO-8601, optional)'**
  String get expiresAtOptional;

  /// No description provided for @createTokenCta.
  ///
  /// In en, this message translates to:
  /// **'Create token'**
  String get createTokenCta;

  /// No description provided for @revokeToken.
  ///
  /// In en, this message translates to:
  /// **'Revoke Token'**
  String get revokeToken;

  /// No description provided for @tokenId.
  ///
  /// In en, this message translates to:
  /// **'Token id'**
  String get tokenId;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @tokensHeading.
  ///
  /// In en, this message translates to:
  /// **'Tokens ({count})'**
  String tokensHeading(int count);

  /// No description provided for @downloadLogsHeading.
  ///
  /// In en, this message translates to:
  /// **'Download Logs ({count})'**
  String downloadLogsHeading(int count);

  /// No description provided for @tokenCreated.
  ///
  /// In en, this message translates to:
  /// **'Token created: {token}'**
  String tokenCreated(Object token);

  /// No description provided for @tokenRevoked.
  ///
  /// In en, this message translates to:
  /// **'Token revoked: {tokenId}'**
  String tokenRevoked(Object tokenId);

  /// No description provided for @enterTokenIdToRevoke.
  ///
  /// In en, this message translates to:
  /// **'Enter token id to revoke'**
  String get enterTokenIdToRevoke;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'id'**
  String get id;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get owner;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'status'**
  String get status;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'created_at'**
  String get createdAt;

  /// No description provided for @expiresAt.
  ///
  /// In en, this message translates to:
  /// **'expires_at'**
  String get expiresAt;

  /// No description provided for @lastUsedAt.
  ///
  /// In en, this message translates to:
  /// **'last_used_at'**
  String get lastUsedAt;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'token'**
  String get token;

  /// No description provided for @package.
  ///
  /// In en, this message translates to:
  /// **'package'**
  String get package;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'version'**
  String get version;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'timestamp'**
  String get timestamp;

  /// No description provided for @ip.
  ///
  /// In en, this message translates to:
  /// **'ip'**
  String get ip;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
