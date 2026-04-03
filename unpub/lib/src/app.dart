import 'dart:convert';
import 'dart:io';
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
  }) : adminEmails = adminEmails ?? <String>{};

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

        final isAllowed = hasDbTokenStore
            ? await tokenStore!.isValidToken(token)
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

        final res = await innerHandler(req);
        if (hasDbTokenStore) {
          await tokenStore!.markTokenUsed(token);
          if (resource.kind == _ProtectedResourceKind.download) {
            await tokenStore!.logDownload(
              token: token,
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

  @Route.post('/admin/tokens')
  Future<shelf.Response> createToken(shelf.Request req) async {
    if (tokenStore == null) {
      return _badRequest(
        'token store not configured',
        status: HttpStatus.serviceUnavailable,
      );
    }

    final operatorEmail = await _getUploaderEmail(req);
    final bodyRaw = await req.readAsString();
    final body = bodyRaw.trim().isEmpty
        ? <String, dynamic>{}
        : (json.decode(bodyRaw) as Map<String, dynamic>);

    final requestedOwner = body['owner_name']?.toString().trim();
    final owner = (requestedOwner == null || requestedOwner.isEmpty)
        ? operatorEmail
        : requestedOwner;
    if (!_isAdmin(operatorEmail) && owner != operatorEmail) {
      return _badRequest('no permission', status: HttpStatus.forbidden);
    }

    final expiresAt = body['expires_at']?.toString().trim();
    if (expiresAt != null && expiresAt.isNotEmpty) {
      try {
        DateTime.parse(expiresAt);
      } catch (_) {
        return _badRequest('invalid expires_at (ISO-8601 expected)');
      }
    }

    final created = await tokenStore!.createToken(
      ownerName: owner,
      expiresAt: expiresAt == null || expiresAt.isEmpty ? null : expiresAt,
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

    final operatorEmail = await _getUploaderEmail(req);
    final includeAll = req.requestedUri.queryParameters['all'] == '1';
    final canListAll = includeAll && _isAdmin(operatorEmail);
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

    final operatorEmail = await _getUploaderEmail(req);
    final revoked = await tokenStore!.revokeToken(
      id: tokenId,
      ownerName: _isAdmin(operatorEmail) ? null : operatorEmail,
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

    final operatorEmail = await _getUploaderEmail(req);
    final includeAll = req.requestedUri.queryParameters['all'] == '1';
    final canListAll = includeAll && _isAdmin(operatorEmail);
    final limit = int.tryParse(req.requestedUri.queryParameters['limit'] ?? '');
    final downloads = await tokenStore!.listDownloads(
      ownerName: canListAll ? null : operatorEmail,
      limit: limit ?? 100,
    );
    return _okWithJson({
      'data': [for (final row in downloads) row.toJson()],
    });
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
