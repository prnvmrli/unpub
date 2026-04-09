import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:googleapis/oauth2/v2.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:archive/archive.dart';
import 'package:unpub/src/models.dart';
import 'package:unpub/unpub_api/lib/models.dart';
import 'package:unpub/src/meta_store.dart';
import 'package:unpub/src/package_store.dart';
import 'package:unpub/src/token_store.dart';
import 'utils.dart';
import 'static/index.html.dart' as index_html;
import 'static/main.dart.js.dart' as main_dart_js;

part 'app.g.dart';

class App {
  static const proxyOriginHeader = "proxy-origin";
  static const _downloadPathPattern =
      r'^/packages/([^/]+)/versions/(.+)\.tar\.gz$';
  static const _packageMetadataPathPattern = r'^/api/packages/([^/]+)$';
  static const _versionMetadataPathPattern =
      r'^/api/packages/([^/]+)/versions/(.+)$';
  static const _packageVersionsPathPattern = r'^/packages/([^/]+)\.json$';
  static const _sessionCookieName = 'unpub_session';
  static const _sessionContextKey = 'unpub.session';

  /// meta information store
  final MetaStore metaStore;

  /// package(tarball) store
  final PackageStore packageStore;

  /// upstream url, default: https://pub.dev
  final String upstream;

  /// http(s) proxy to call googleapis (to get uploader email)
  final String? googleapisProxy;
  final String? overrideUploaderEmail;

  /// A forward proxy uri
  final Uri? proxy_origin;
  final String? webRoot;
  final String? downloadToken;
  final TokenStore? tokenStore;
  final Set<String> adminEmails;
  final Duration sessionTtl;
  final Map<String, _SessionRecord> _sessions = {};

  /// validate if the package can be published
  ///
  /// for more details, see: https://github.com/bytedance/unpub#package-validator
  final Future<void> Function(
    Map<String, dynamic> pubspec,
    String uploaderEmail,
  )?
  uploadValidator;

  App({
    required this.metaStore,
    required this.packageStore,
    this.upstream = 'https://pub.dev',
    this.googleapisProxy,
    this.overrideUploaderEmail,
    this.uploadValidator,
    this.proxy_origin,
    this.webRoot,
    this.downloadToken,
    this.tokenStore,
    Set<String>? adminEmails,
    Duration? sessionTtl,
  }) : adminEmails = adminEmails ?? <String>{},
       sessionTtl = sessionTtl ?? const Duration(hours: 12);

  static shelf.Response _okWithJson(Map<String, dynamic> data) =>
      shelf.Response.ok(
        json.encode(data),
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          'Access-Control-Allow-Origin': '*',
        },
      );

  static shelf.Response _successMessage(String message) => _okWithJson({
    'success': {'message': message},
  });

  static shelf.Response _badRequest(
    String message, {
    int status = HttpStatus.badRequest,
  }) => shelf.Response(
    status,
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
    body: json.encode({
      'error': {'message': message},
    }),
  );

  static shelf.Response _unauthorized([String message = 'unauthorized']) =>
      _badRequest(message, status: HttpStatus.unauthorized);

  static shelf.Response _forbidden([String message = 'forbidden']) =>
      _badRequest(message, status: HttpStatus.forbidden);

  http.Client? _googleapisClient;

  String _resolveUrl(shelf.Request req, String reference) {
    if (proxy_origin != null) {
      return proxy_origin!.resolve(reference).toString();
    }
    String? proxyOriginInHeader = req.headers[proxyOriginHeader];
    if (proxyOriginInHeader != null) {
      return Uri.parse(proxyOriginInHeader).resolve(reference).toString();
    }
    return req.requestedUri.resolve(reference).toString();
  }

  Future<String> _getUploaderEmail(shelf.Request req) async {
    if (overrideUploaderEmail != null) return overrideUploaderEmail!;

    var authHeader = req.headers[HttpHeaders.authorizationHeader];
    if (authHeader == null) throw 'missing authorization header';

    final bearerToken = _extractDownloadToken(req);
    if (bearerToken != null && tokenStore != null) {
      final validated = await tokenStore!.validateToken(bearerToken);
      if (validated != null && validated.canPublish) {
        await tokenStore!.markTokenUsed(tokenId: validated.tokenId);
        return validated.ownerName;
      }
    }

    var token = authHeader.split(' ').last;

    if (_googleapisClient == null) {
      if (googleapisProxy != null) {
        _googleapisClient = IOClient(
          HttpClient()
            ..findProxy = (url) => HttpClient.findProxyFromEnvironment(
              url,
              environment: {"https_proxy": googleapisProxy!},
            ),
        );
      } else {
        _googleapisClient = http.Client();
      }
    }

    var info = await Oauth2Api(
      _googleapisClient!,
    ).tokeninfo(accessToken: token);
    if (info.email == null) throw 'fail to get google account email';
    return info.email!;
  }

  Future<HttpServer> serve([String host = '0.0.0.0', int port = 4000]) async {
    var handler = const shelf.Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_sessionValidationMiddleware())
        .addMiddleware(_tokenPermissionMiddleware())
        .addMiddleware(_downloadAuthMiddleware())
        .addHandler((req) async {
          final flutterAsset = await _tryServeFlutterAsset(req);
          if (flutterAsset != null) {
            return flutterAsset;
          }
          // Return 404 by default
          // https://github.com/google/dart-neats/issues/1
          var res = await router.call(req);
          return res;
        });
    var server = await shelf_io.serve(handler, host, port);
    return server;
  }

  shelf.Middleware _downloadAuthMiddleware() {
    return (innerHandler) {
      return (req) async {
        final resource = _parseProtectedResource(req.requestedUri.path);
        if (resource == null) {
          return innerHandler(req);
        }

        final configuredToken = downloadToken?.trim();
        final hasDbTokenStore = tokenStore != null;
        final hasStaticToken =
            configuredToken != null && configuredToken.isNotEmpty;
        if (!hasDbTokenStore && !hasStaticToken) {
          final res = await innerHandler(req);
          _logDownloadAccess(
            allowed: true,
            req: req,
            packageName: resource.packageName,
            version: resource.version,
            statusCode: res.statusCode,
            reason: 'no token configured',
          );
          return res;
        }

        final token = _extractDownloadToken(req);
        if (token == null) {
          _logDownloadAccess(
            allowed: false,
            req: req,
            packageName: resource.packageName,
            version: resource.version,
            statusCode: HttpStatus.unauthorized,
            reason: 'missing bearer token',
          );
          return _badRequest(
            'invalid api key',
            status: HttpStatus.unauthorized,
          );
        }

        final validated = hasDbTokenStore
            ? await tokenStore!.validateToken(token)
            : null;
        final isAllowed = hasDbTokenStore
            ? validated != null
            : token == configuredToken;
        if (!isAllowed) {
          _logDownloadAccess(
            allowed: false,
            req: req,
            packageName: resource.packageName,
            version: resource.version,
            statusCode: HttpStatus.unauthorized,
            reason: hasDbTokenStore
                ? 'token not found in database'
                : 'invalid token',
          );
          return _badRequest(
            'invalid api key',
            status: HttpStatus.unauthorized,
          );
        }
        if (hasDbTokenStore && validated != null && !validated.canDownload) {
          _logDownloadAccess(
            allowed: false,
            req: req,
            packageName: resource.packageName,
            version: resource.version,
            statusCode: HttpStatus.forbidden,
            reason: 'token missing download permission',
          );
          return _forbidden('missing download permission');
        }

        final res = await innerHandler(req);
        if (hasDbTokenStore) {
          if (validated != null) {
            await tokenStore!.markTokenUsed(tokenId: validated.tokenId);
          }
          if (validated != null &&
              resource.kind == _ProtectedResourceKind.download) {
            await tokenStore!.logDownload(
              tokenId: validated.tokenId,
              userId: validated.userId,
              packageName: resource.packageName,
              version: resource.version,
              ipAddress: _extractClientIp(req),
            );
          }
        }
        _logDownloadAccess(
          allowed: true,
          req: req,
          packageName: resource.packageName,
          version: resource.version,
          statusCode: res.statusCode,
          reason: hasDbTokenStore ? 'authorized via token db' : 'authorized',
        );
        return res;
      };
    };
  }

  shelf.Middleware _tokenPermissionMiddleware() {
    return (innerHandler) {
      return (req) async {
        if (tokenStore == null) return innerHandler(req);

        final isPublishRoute = _isPublishRoute(req);
        if (!isPublishRoute) return innerHandler(req);

        final token = _extractDownloadToken(req);
        if (token == null) return innerHandler(req);

        final validated = await tokenStore!.validateToken(token);
        if (validated == null) return innerHandler(req);
        if (!validated.canPublish) {
          return _forbidden('missing publish permission');
        }
        return innerHandler(req);
      };
    };
  }

  bool _isPublishRoute(shelf.Request req) {
    final path = req.requestedUri.path;
    if (req.method == 'POST' && path == '/api/packages/versions/newUpload') {
      return true;
    }

    if (req.method == 'POST' &&
        RegExp(r'^/api/packages/[^/]+/uploaders$').hasMatch(path)) {
      return true;
    }

    if (req.method == 'DELETE' &&
        RegExp(r'^/api/packages/[^/]+/uploaders/[^/]+$').hasMatch(path)) {
      return true;
    }

    return false;
  }

  _ProtectedResource? _parseProtectedResource(String path) {
    final download = _parseDownloadPath(path);
    if (download != null) {
      return _ProtectedResource(
        kind: _ProtectedResourceKind.download,
        packageName: download.$1,
        version: download.$2,
      );
    }

    final packageMeta = RegExp(_packageMetadataPathPattern).firstMatch(path);
    if (packageMeta != null) {
      return _ProtectedResource(
        kind: _ProtectedResourceKind.metadata,
        packageName: Uri.decodeComponent(packageMeta.group(1)!),
        version: 'latest',
      );
    }

    final versionMeta = RegExp(_versionMetadataPathPattern).firstMatch(path);
    if (versionMeta != null) {
      return _ProtectedResource(
        kind: _ProtectedResourceKind.metadata,
        packageName: Uri.decodeComponent(versionMeta.group(1)!),
        version: Uri.decodeComponent(versionMeta.group(2)!),
      );
    }

    final packageVersions = RegExp(
      _packageVersionsPathPattern,
    ).firstMatch(path);
    if (packageVersions != null) {
      return _ProtectedResource(
        kind: _ProtectedResourceKind.metadata,
        packageName: Uri.decodeComponent(packageVersions.group(1)!),
        version: 'all',
      );
    }

    return null;
  }

  (String, String)? _parseDownloadPath(String path) {
    final match = RegExp(_downloadPathPattern).firstMatch(path);
    if (match == null) return null;

    final name = Uri.decodeComponent(match.group(1)!);
    final version = Uri.decodeComponent(match.group(2)!);
    return (name, version);
  }

  String? _extractDownloadToken(shelf.Request req) {
    final auth = req.headers[HttpHeaders.authorizationHeader];
    if (auth != null && auth.startsWith('Bearer ')) {
      final bearerToken = auth.substring('Bearer '.length).trim();
      if (bearerToken.isNotEmpty) return bearerToken;
    }

    return null;
  }

  String? _cookieValue(shelf.Request req, String name) {
    final cookieHeader = req.headers[HttpHeaders.cookieHeader];
    if (cookieHeader == null || cookieHeader.trim().isEmpty) return null;

    for (final part in cookieHeader.split(';')) {
      final item = part.trim();
      if (!item.startsWith('$name=')) continue;
      return Uri.decodeComponent(item.substring(name.length + 1));
    }
    return null;
  }

  String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  shelf.Middleware _sessionValidationMiddleware() {
    return (innerHandler) {
      return (req) async {
        final session = _sessionFromCookie(req);
        if (session == null) {
          return innerHandler(req);
        }
        return innerHandler(
          req.change(context: {...req.context, _sessionContextKey: session}),
        );
      };
    };
  }

  _SessionRecord? _sessionFromCookie(shelf.Request req) {
    final sessionId = _cookieValue(req, _sessionCookieName);
    if (sessionId == null || sessionId.isEmpty) return null;

    final session = _sessions[sessionId];
    if (session == null) return null;
    if (session.expiresAt.isBefore(DateTime.now().toUtc())) {
      _sessions.remove(sessionId);
      return null;
    }
    return session;
  }

  _SessionRecord? _activeSession(shelf.Request req) {
    final fromContext = req.context[_sessionContextKey];
    if (fromContext is _SessionRecord) {
      return fromContext;
    }
    return _sessionFromCookie(req);
  }

  Future<_OperatorIdentity?> _operatorFromBearerToken(shelf.Request req) async {
    final token = _extractDownloadToken(req);
    if (token == null) return null;

    if (tokenStore != null) {
      final validated = await tokenStore!.validateToken(token);
      if (validated != null) {
        return _OperatorIdentity(ownerName: validated.ownerName, token: token);
      }
    }
    final configuredToken = downloadToken?.trim();
    if (configuredToken != null &&
        configuredToken.isNotEmpty &&
        configuredToken == token) {
      return _OperatorIdentity(ownerName: 'static-token-user', token: token);
    }
    return null;
  }

  Future<_OperatorIdentity?> _operatorFromGoogleAccessToken(
    shelf.Request req,
  ) async {
    try {
      final uploaderEmail = await _getUploaderEmail(req);
      return _OperatorIdentity(ownerName: uploaderEmail, token: null);
    } catch (_) {
      return null;
    }
  }

  Future<_OperatorIdentity?> _authenticateOperator(shelf.Request req) async {
    final session = _activeSession(req);
    if (session != null) {
      return _OperatorIdentity(
        ownerName: session.ownerName,
        token: session.token,
      );
    }

    final bearerIdentity = await _operatorFromBearerToken(req);
    if (bearerIdentity != null) return bearerIdentity;

    return _operatorFromGoogleAccessToken(req);
  }

  shelf.Response _withSessionCookie(
    shelf.Response res, {
    required String sessionId,
  }) {
    final cookie =
        '$_sessionCookieName=$sessionId; Path=/; HttpOnly; SameSite=Lax; Max-Age=${sessionTtl.inSeconds}';
    return res.change(
      headers: {...res.headers, HttpHeaders.setCookieHeader: cookie},
    );
  }

  shelf.Response _clearSessionCookie(shelf.Response res) {
    final cookie =
        '$_sessionCookieName=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0';
    return res.change(
      headers: {...res.headers, HttpHeaders.setCookieHeader: cookie},
    );
  }

  void _logDownloadAccess({
    required bool allowed,
    required shelf.Request req,
    required String packageName,
    required String version,
    required int statusCode,
    required String reason,
  }) {
    final remote =
        _extractClientIp(req) ?? req.context['shelf.io.connection_info'];
    print(
      '[download-access] '
      'allowed=$allowed '
      'status=$statusCode '
      'package=$packageName '
      'version=$version '
      'method=${req.method} '
      'remote=$remote '
      'reason=$reason',
    );
  }

  String? _extractClientIp(shelf.Request req) {
    final forwardedFor = req.headers['x-forwarded-for'];
    if (forwardedFor != null && forwardedFor.trim().isNotEmpty) {
      return forwardedFor.split(',').first.trim();
    }

    final connectionInfo = req.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      return connectionInfo.remoteAddress.address;
    }

    return null;
  }

  Map<String, dynamic> _versionToJson(UnpubVersion item, shelf.Request req) {
    var name = item.pubspec['name'] as String;
    var version = item.version;
    return {
      'archive_url': _resolveUrl(
        req,
        '/packages/$name/versions/$version.tar.gz',
      ),
      'pubspec': item.pubspec,
      'version': version,
    };
  }

  bool isPubClient(shelf.Request req) {
    var ua = req.headers[HttpHeaders.userAgentHeader];
    print(ua);
    return ua != null && ua.toLowerCase().contains('dart pub');
  }

  File? _webFile(String relativePath) {
    if (webRoot == null) return null;
    final cleanPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final file = File(path.join(webRoot!, cleanPath));
    return file.existsSync() ? file : null;
  }

  Future<shelf.Response?> _serveWebAsset(String relativePath) async {
    final file = _webFile(relativePath);
    if (file == null) return null;

    final contentType =
        lookupMimeType(file.path) ?? ContentType.binary.mimeType;
    return shelf.Response.ok(
      file.openRead(),
      headers: {HttpHeaders.contentTypeHeader: contentType},
    );
  }

  Future<shelf.Response?> _tryServeFlutterAsset(shelf.Request req) async {
    var path = req.requestedUri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.isEmpty) return null;

    const topLevelAssets = <String>{
      'flutter.js',
      'flutter_bootstrap.js',
      'flutter_service_worker.js',
      'manifest.json',
      'version.json',
      'favicon.ico',
      'favicon.png',
      'main.dart.js',
      'main.dart.js.map',
    };

    if (topLevelAssets.contains(path)) {
      return _serveWebAsset(path);
    }

    if (path.startsWith('assets/') ||
        path.startsWith('icons/') ||
        path.startsWith('canvaskit/')) {
      return _serveWebAsset(path);
    }

    return null;
  }

  Router get router => _$AppRouter(this);

  @Route.get('/api/packages/<name>')
  Future<shelf.Response> getVersions(shelf.Request req, String name) async {
    var package = await metaStore.queryPackage(name);

    if (package == null) {
      return shelf.Response.found(
        Uri.parse(upstream).resolve('/api/packages/$name').toString(),
      );
    }

    package.versions.sort((a, b) {
      return semver.Version.prioritize(
        semver.Version.parse(a.version),
        semver.Version.parse(b.version),
      );
    });

    var versionMaps = package.versions
        .map((item) => _versionToJson(item, req))
        .toList();

    return _okWithJson({
      'name': name,
      'latest': versionMaps.last, // TODO: Exclude pre release
      'versions': versionMaps,
    });
  }

  @Route.get('/api/packages/<name>/versions/<version>')
  Future<shelf.Response> getVersion(
    shelf.Request req,
    String name,
    String version,
  ) async {
    // Important: + -> %2B, should be decoded here
    try {
      version = Uri.decodeComponent(version);
    } catch (err) {
      print(err);
    }

    var package = await metaStore.queryPackage(name);
    if (package == null) {
      return shelf.Response.found(
        Uri.parse(
          upstream,
        ).resolve('/api/packages/$name/versions/$version').toString(),
      );
    }

    var packageVersion = package.versions.firstWhereOrNull(
      (item) => item.version == version,
    );
    if (packageVersion == null) {
      return shelf.Response.notFound('Not Found');
    }

    return _okWithJson(_versionToJson(packageVersion, req));
  }

  @Route.get('/packages/<name>/versions/<version>.tar.gz')
  Future<shelf.Response> download(
    shelf.Request req,
    String name,
    String version,
  ) async {
    var package = await metaStore.queryPackage(name);
    if (package == null) {
      return shelf.Response.found(
        Uri.parse(
          upstream,
        ).resolve('/packages/$name/versions/$version.tar.gz').toString(),
      );
    }

    if (isPubClient(req)) {
      metaStore.increaseDownloads(name, version);
    }

    if (packageStore.supportsDownloadUrl) {
      return shelf.Response.found(
        await packageStore.downloadUrl(name, version),
      );
    } else {
      return shelf.Response.ok(
        packageStore.download(name, version),
        headers: {HttpHeaders.contentTypeHeader: ContentType.binary.mimeType},
      );
    }
  }

  @Route.get('/api/packages/versions/new')
  Future<shelf.Response> getUploadUrl(shelf.Request req) async {
    return _okWithJson({
      'url': _resolveUrl(req, '/api/packages/versions/newUpload').toString(),
      'fields': {},
    });
  }

  @Route.post('/api/packages/versions/newUpload')
  Future<shelf.Response> upload(shelf.Request req) async {
    try {
      var uploader = await _getUploaderEmail(req);

      var contentType = req.headers['content-type'];
      if (contentType == null) throw 'invalid content type';

      var mediaType = MediaType.parse(contentType);
      var boundary = mediaType.parameters['boundary'];
      if (boundary == null) throw 'invalid boundary';

      var transformer = MimeMultipartTransformer(boundary);
      MimeMultipart? fileData;

      // The map below makes the runtime type checker happy.
      // https://github.com/dart-lang/pub-dev/blob/19033f8154ca1f597ef5495acbc84a2bb368f16d/app/lib/fake/server/fake_storage_server.dart#L74
      final stream = req.read().map((a) => a).transform(transformer);
      await for (var part in stream) {
        if (fileData != null) continue;
        fileData = part;
      }

      var bb = await fileData!.fold(
        BytesBuilder(),
        (BytesBuilder byteBuilder, d) => byteBuilder..add(d),
      );
      var tarballBytes = bb.takeBytes();
      var tarBytes = GZipDecoder().decodeBytes(tarballBytes);
      var archive = TarDecoder().decodeBytes(tarBytes);
      ArchiveFile? pubspecArchiveFile;
      ArchiveFile? readmeFile;
      ArchiveFile? changelogFile;

      for (var file in archive.files) {
        if (file.name == 'pubspec.yaml') {
          pubspecArchiveFile = file;
          continue;
        }
        if (file.name.toLowerCase() == 'readme.md') {
          readmeFile = file;
          continue;
        }
        if (file.name.toLowerCase() == 'changelog.md') {
          changelogFile = file;
          continue;
        }
      }

      if (pubspecArchiveFile == null) {
        throw 'Did not find any pubspec.yaml file in upload. Aborting.';
      }

      var pubspecYaml = utf8.decode(pubspecArchiveFile.content);
      var pubspec = loadYamlAsMap(pubspecYaml)!;

      if (uploadValidator != null) {
        await uploadValidator!(pubspec, uploader);
      }

      // TODO: null
      var name = pubspec['name'] as String;
      var version = pubspec['version'] as String;

      var package = await metaStore.queryPackage(name);

      // Package already exists
      if (package != null) {
        if (package.private == false) {
          throw '$name is not a private package. Please upload it to https://pub.dev';
        }

        // Check uploaders
        if (package.uploaders?.contains(uploader) == false) {
          throw '$uploader is not an uploader of $name';
        }

        // Check duplicated version
        var duplicated = package.versions.firstWhereOrNull(
          (item) => version == item.version,
        );
        if (duplicated != null) {
          throw 'version invalid: $name@$version already exists.';
        }
      }

      // Upload package tarball to storage
      await packageStore.upload(name, version, tarballBytes);

      String? readme;
      String? changelog;
      if (readmeFile != null) {
        readme = utf8.decode(readmeFile.content);
      }
      if (changelogFile != null) {
        changelog = utf8.decode(changelogFile.content);
      }

      // Write package meta to database
      var unpubVersion = UnpubVersion(
        version,
        pubspec,
        pubspecYaml,
        uploader,
        readme,
        changelog,
        DateTime.now(),
      );
      await metaStore.addVersion(name, unpubVersion);

      // TODO: Upload docs
      return shelf.Response.found(
        _resolveUrl(req, '/api/packages/versions/newUploadFinish'),
      );
    } catch (err) {
      return shelf.Response.found(
        _resolveUrl(req, '/api/packages/versions/newUploadFinish?error=$err'),
      );
    }
  }

  @Route.get('/api/packages/versions/newUploadFinish')
  Future<shelf.Response> uploadFinish(shelf.Request req) async {
    var error = req.requestedUri.queryParameters['error'];
    if (error != null) {
      return _badRequest(error);
    }
    return _successMessage('Successfully uploaded package.');
  }

  @Route.post('/api/packages/<name>/uploaders')
  Future<shelf.Response> addUploader(shelf.Request req, String name) async {
    var body = await req.readAsString();
    var email = Uri.splitQueryString(body)['email']!; // TODO: null
    var operatorEmail = await _getUploaderEmail(req);
    var package = await metaStore.queryPackage(name);

    if (package?.uploaders?.contains(operatorEmail) == false) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }
    if (package?.uploaders?.contains(email) == true) {
      return _badRequest('email already exists');
    }

    await metaStore.addUploader(name, email);
    return _successMessage('uploader added');
  }

  @Route.delete('/api/packages/<name>/uploaders/<email>')
  Future<shelf.Response> removeUploader(
    shelf.Request req,
    String name,
    String email,
  ) async {
    email = Uri.decodeComponent(email);
    var operatorEmail = await _getUploaderEmail(req);
    var package = await metaStore.queryPackage(name);

    // TODO: null
    if (package?.uploaders?.contains(operatorEmail) == false) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }
    if (package?.uploaders?.contains(email) == false) {
      return _badRequest('email not uploader');
    }

    await metaStore.removeUploader(name, email);
    return _successMessage('uploader removed');
  }

  bool _isAdmin(String email) => adminEmails.contains(email);

  Future<bool> _isOperatorAdmin(String ownerName) async {
    if (_isAdmin(ownerName)) return true;
    if (tokenStore == null) return false;
    final user = await tokenStore!.findUserByEmail(ownerName);
    return user?.role == 'admin';
  }

  @Route.post('/auth/login')
  Future<shelf.Response> login(shelf.Request req) async {
    final bodyRaw = await req.readAsString();
    final body = bodyRaw.trim().isEmpty
        ? <String, dynamic>{}
        : (json.decode(bodyRaw) as Map<String, dynamic>);

    final email = body['email']?.toString().trim();
    final password = body['password']?.toString() ?? '';
    if (email != null && email.isNotEmpty && password.isNotEmpty) {
      if (tokenStore == null) {
        return _badRequest(
          'token store not configured',
          status: HttpStatus.serviceUnavailable,
        );
      }
      final user = await tokenStore!.authenticateUser(
        email: email,
        password: password,
      );
      if (user == null) {
        return _unauthorized('invalid credentials');
      }

      final sessionId = _newSessionId();
      _sessions[sessionId] = _SessionRecord(
        sessionId: sessionId,
        ownerName: user.email,
        token: null,
        userId: user.id,
        email: user.email,
        role: user.role,
        expiresAt: DateTime.now().toUtc().add(sessionTtl),
      );

      return _withSessionCookie(
        _okWithJson({
          'data': {
            'user': {'id': user.id, 'email': user.email, 'role': user.role},
            'owner_name': user.email,
          },
        }),
        sessionId: sessionId,
      );
    }

    final token = body['token']?.toString().trim();
    if (token == null || token.isEmpty) {
      return _unauthorized('invalid credentials');
    }

    String? ownerName;
    if (tokenStore != null) {
      final validated = await tokenStore!.validateToken(token);
      if (validated == null) return _unauthorized('invalid credentials');
      ownerName = validated.ownerName;
      await tokenStore!.markTokenUsed(tokenId: validated.tokenId);
    } else {
      final configuredToken = downloadToken?.trim();
      if (configuredToken == null ||
          configuredToken.isEmpty ||
          configuredToken != token) {
        return _unauthorized('invalid credentials');
      }
      ownerName = 'static-token-user';
    }

    final sessionId = _newSessionId();
    _sessions[sessionId] = _SessionRecord(
      sessionId: sessionId,
      ownerName: ownerName,
      token: token,
      userId: null,
      email: ownerName,
      role: null,
      expiresAt: DateTime.now().toUtc().add(sessionTtl),
    );

    return _withSessionCookie(
      _okWithJson({
        'data': {'owner_name': ownerName},
      }),
      sessionId: sessionId,
    );
  }

  @Route.get('/auth/me')
  Future<shelf.Response> me(shelf.Request req) async {
    final session = _activeSession(req);
    if (session == null) {
      return _unauthorized('not logged in');
    }
    return _okWithJson({
      'data': {
        'owner_name': session.ownerName,
        if (session.userId != null && session.email != null)
          'user': {
            'id': session.userId,
            'email': session.email,
            'role': session.role,
          },
      },
    });
  }

  @Route.post('/auth/logout')
  Future<shelf.Response> logout(shelf.Request req) async {
    final session = _activeSession(req);
    if (session != null) {
      _sessions.remove(session.sessionId);
    }
    return _clearSessionCookie(_successMessage('logged out'));
  }

  @Route.post('/admin/tokens')
  Future<shelf.Response> createToken(shelf.Request req) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final operator = await _authenticateOperator(req);
    if (operator == null) return _unauthorized();
    final operatorEmail = operator.ownerName;
    final bodyRaw = await req.readAsString();
    final body = bodyRaw.trim().isEmpty
        ? <String, dynamic>{}
        : (json.decode(bodyRaw) as Map<String, dynamic>);

    final requestedOwner = body['owner_name']?.toString().trim();
    final owner = (requestedOwner == null || requestedOwner.isEmpty)
        ? operatorEmail
        : requestedOwner;
    final isOperatorAdmin = await _isOperatorAdmin(operatorEmail);
    if (!isOperatorAdmin && owner != operatorEmail) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }

    final tokenName = body['name']?.toString().trim();
    if (tokenName == null || tokenName.isEmpty) {
      return _badRequest('name is required');
    }

    final expiryDaysRaw = body['expiry_days']?.toString().trim();
    int? expiryDays;
    if (expiryDaysRaw != null && expiryDaysRaw.isNotEmpty) {
      expiryDays = int.tryParse(expiryDaysRaw);
      if (expiryDays == null || expiryDays < 1 || expiryDays > 3650) {
        return _badRequest('invalid expiry_days');
      }
    }

    final canDownload = body['can_download'] != false;
    final canPublish = body['can_publish'] == true;
    if (!canDownload && !canPublish) {
      return _badRequest('at least one permission is required');
    }

    String? expiresAt;
    if (expiryDays != null) {
      expiresAt = DateTime.now()
          .toUtc()
          .add(Duration(days: expiryDays))
          .toIso8601String();
    } else {
      final expiresAtRaw = body['expires_at']?.toString().trim();
      if (expiresAtRaw != null && expiresAtRaw.isNotEmpty) {
        try {
          expiresAt = DateTime.parse(expiresAtRaw).toUtc().toIso8601String();
        } catch (_) {
          return _badRequest('invalid expires_at (ISO-8601 expected)');
        }
      }
    }

    final created = await tokenStore!.createToken(
      ownerName: owner,
      name: tokenName,
      expiresAt: expiresAt == null || expiresAt.isEmpty ? null : expiresAt,
      canDownload: canDownload,
      canPublish: canPublish,
    );
    return _okWithJson({'data': created.toJson()});
  }

  @Route.get('/admin/tokens/me')
  Future<shelf.Response> listMyTokens(shelf.Request req) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final operator = await _authenticateOperator(req);
    if (operator == null) return _unauthorized();
    final operatorEmail = operator.ownerName;
    final includeAll = req.requestedUri.queryParameters['all'] == '1';
    final canListAll = includeAll && (await _isOperatorAdmin(operatorEmail));
    final tokens = await tokenStore!.listTokens(
      ownerName: canListAll ? null : operatorEmail,
    );
    return _okWithJson({
      'data': [for (final token in tokens) token.toJson()],
    });
  }

  @Route.post('/admin/tokens/<id>/revoke')
  Future<shelf.Response> revokeToken(shelf.Request req, String id) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final tokenId = int.tryParse(id);
    if (tokenId == null) {
      return _badRequest('invalid token id');
    }

    final operator = await _authenticateOperator(req);
    if (operator == null) return _unauthorized();
    final operatorEmail = operator.ownerName;
    final isOperatorAdmin = await _isOperatorAdmin(operatorEmail);
    final revoked = await tokenStore!.revokeToken(
      id: tokenId,
      ownerName: isOperatorAdmin ? null : operatorEmail,
    );
    if (!revoked) {
      return _badRequest('token not found', status: HttpStatus.notFound);
    }

    return _successMessage('token revoked');
  }

  @Route.get('/admin/downloads')
  Future<shelf.Response> listDownloads(shelf.Request req) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final operator = await _authenticateOperator(req);
    if (operator == null) return _unauthorized();
    final operatorEmail = operator.ownerName;
    final includeAll = req.requestedUri.queryParameters['all'] == '1';
    final canListAll = includeAll && (await _isOperatorAdmin(operatorEmail));
    final limit = int.tryParse(req.requestedUri.queryParameters['limit'] ?? '');
    final downloads = await tokenStore!.listDownloads(
      ownerName: canListAll ? null : operatorEmail,
      limit: limit ?? 100,
    );
    return _okWithJson({
      'data': [for (final row in downloads) row.toJson()],
    });
  }

  @Route.get('/admin/users')
  Future<shelf.Response> listUsers(shelf.Request req) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final operator = await _authenticateOperator(req);
    if (operator == null) return _unauthorized();
    final canManageUsers = await _isOperatorAdmin(operator.ownerName);
    if (!canManageUsers) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }

    final users = await tokenStore!.listUsers();
    return _okWithJson({
      'data': [for (final user in users) user.toJson()],
    });
  }

  @Route.post('/admin/users/<id>/disable')
  Future<shelf.Response> disableUser(shelf.Request req, String id) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final operator = await _authenticateOperator(req);
    if (operator == null) return _unauthorized();
    final canManageUsers = await _isOperatorAdmin(operator.ownerName);
    if (!canManageUsers) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }

    final userId = int.tryParse(id);
    if (userId == null) {
      return _badRequest('invalid user id');
    }

    final disabled = await tokenStore!.disableUser(userId);
    if (!disabled) {
      return _badRequest('user not found', status: HttpStatus.notFound);
    }
    return _successMessage('user disabled');
  }

  @Route.get('/webapi/packages')
  Future<shelf.Response> getPackages(shelf.Request req) async {
    var params = req.requestedUri.queryParameters;
    var size = int.tryParse(params['size'] ?? '') ?? 10;
    var page = int.tryParse(params['page'] ?? '') ?? 0;
    var sort = params['sort'] ?? 'download';
    var q = params['q'];

    String? keyword;
    String? uploader;
    String? dependency;

    if (q == null) {
    } else if (q.startsWith('email:')) {
      uploader = q.substring(6).trim();
    } else if (q.startsWith('dependency:')) {
      dependency = q.substring(11).trim();
    } else {
      keyword = q;
    }

    final result = await metaStore.queryPackages(
      size: size,
      page: page,
      sort: sort,
      keyword: keyword,
      uploader: uploader,
      dependency: dependency,
    );

    var data = ListApi(result.count, [
      for (var package in result.packages)
        ListApiPackage(
          package.name,
          package.versions.last.pubspec['description'] as String?,
          getPackageTags(package.versions.last.pubspec),
          package.versions.last.version,
          package.updatedAt,
        ),
    ]);

    return _okWithJson({'data': data.toJson()});
  }

  @Route.get('/packages/<name>.json')
  Future<shelf.Response> getPackageVersions(
    shelf.Request req,
    String name,
  ) async {
    var package = await metaStore.queryPackage(name);
    if (package == null) {
      return _badRequest('package not exists', status: HttpStatus.notFound);
    }

    var versions = package.versions.map((v) => v.version).toList();
    versions.sort((a, b) {
      return semver.Version.prioritize(
        semver.Version.parse(b),
        semver.Version.parse(a),
      );
    });

    return _okWithJson({'name': name, 'versions': versions});
  }

  @Route.get('/webapi/package/<name>/<version>')
  Future<shelf.Response> getPackageDetail(
    shelf.Request req,
    String name,
    String version,
  ) async {
    var package = await metaStore.queryPackage(name);
    if (package == null) {
      return _okWithJson({'error': 'package not exists'});
    }

    UnpubVersion? packageVersion;
    if (version == 'latest') {
      packageVersion = package.versions.last;
    } else {
      packageVersion = package.versions.firstWhereOrNull(
        (item) => item.version == version,
      );
    }
    if (packageVersion == null) {
      return _okWithJson({'error': 'version not exists'});
    }

    var versions = package.versions
        .map((v) => DetailViewVersion(v.version, v.createdAt))
        .toList();
    versions.sort((a, b) {
      return semver.Version.prioritize(
        semver.Version.parse(b.version),
        semver.Version.parse(a.version),
      );
    });

    var pubspec = packageVersion.pubspec;
    List<String?> authors;
    if (pubspec['author'] != null) {
      authors = RegExp(
        r'<(.*?)>',
      ).allMatches(pubspec['author']).map((match) => match.group(1)).toList();
    } else if (pubspec['authors'] != null) {
      authors = (pubspec['authors'] as List)
          .map((author) => RegExp(r'<(.*?)>').firstMatch(author)!.group(1))
          .toList();
    } else {
      authors = [];
    }

    var depMap = (pubspec['dependencies'] as Map? ?? {}).cast<String, String>();

    var data = WebapiDetailView(
      package.name,
      packageVersion.version,
      packageVersion.pubspec['description'] ?? '',
      packageVersion.pubspec['homepage'] ?? '',
      package.uploaders ?? [],
      packageVersion.createdAt,
      packageVersion.readme,
      packageVersion.changelog,
      versions,
      authors,
      depMap.keys.toList(),
      getPackageTags(packageVersion.pubspec),
    );

    return _okWithJson({'data': data.toJson()});
  }

  @Route.get('/')
  @Route.get('/packages')
  @Route.get('/packages/<name>')
  @Route.get('/packages/<name>/versions/<version>')
  @Route.get('/admin/tokens')
  @Route.get('/login')
  Future<shelf.Response> indexHtml(shelf.Request req) async {
    final webAsset = await _serveWebAsset('index.html');
    if (webAsset != null) return webAsset;
    return shelf.Response.ok(
      index_html.content,
      headers: {HttpHeaders.contentTypeHeader: ContentType.html.mimeType},
    );
  }

  @Route.get('/main.dart.js')
  Future<shelf.Response> mainDartJs(shelf.Request req) async {
    final webAsset = await _serveWebAsset('main.dart.js');
    if (webAsset != null) return webAsset;
    return shelf.Response.ok(
      main_dart_js.content,
      headers: {HttpHeaders.contentTypeHeader: 'text/javascript'},
    );
  }

  String _getBadgeUrl(
    String label,
    String message,
    String color,
    Map<String, String> queryParameters,
  ) {
    var badgeUri = Uri.parse('https://img.shields.io/static/v1');
    return Uri(
      scheme: badgeUri.scheme,
      host: badgeUri.host,
      path: badgeUri.path,
      queryParameters: {
        'label': label,
        'message': message,
        'color': color,
        ...queryParameters,
      },
    ).toString();
  }

  @Route.get('/badge/<type>/<name>')
  Future<shelf.Response> badge(
    shelf.Request req,
    String type,
    String name,
  ) async {
    var queryParameters = req.requestedUri.queryParameters;
    var package = await metaStore.queryPackage(name);
    if (package == null) {
      return shelf.Response.notFound('Not found');
    }

    switch (type) {
      case 'v':
        var latest = semver.Version.primary(
          package.versions
              .map((pv) => semver.Version.parse(pv.version))
              .toList(),
        );

        var color = latest.major == 0 ? 'orange' : 'blue';

        return shelf.Response.found(
          _getBadgeUrl('unpub', latest.toString(), color, queryParameters),
        );
      case 'd':
        return shelf.Response.found(
          _getBadgeUrl(
            'downloads',
            package.download.toString(),
            'blue',
            queryParameters,
          ),
        );
      default:
        return shelf.Response.notFound('Not found');
    }
  }
}

enum _ProtectedResourceKind { download, metadata }

class _ProtectedResource {
  final _ProtectedResourceKind kind;
  final String packageName;
  final String version;

  _ProtectedResource({
    required this.kind,
    required this.packageName,
    required this.version,
  });
}

class _SessionRecord {
  final String sessionId;
  final String ownerName;
  final String? token;
  final int? userId;
  final String? email;
  final String? role;
  final DateTime expiresAt;

  _SessionRecord({
    required this.sessionId,
    required this.ownerName,
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
    required this.expiresAt,
  });
}

class _OperatorIdentity {
  final String ownerName;
  final String? token;

  _OperatorIdentity({required this.ownerName, required this.token});
}
