import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : _baseUri = _normalizeBaseUri(baseUrl),
      _client = client ?? createHttpClient();

  final Uri _baseUri;
  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _resolveUri(path, queryParameters: queryParameters);
    final response = await _client.get(uri, headers: headers);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = _resolveUri(path);
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json', ...?headers},
      body: json.encode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
  }

  Future<Map<String, dynamic>> getCurrentUser() => get('/auth/me');

  Future<Map<String, dynamic>> createToken({
    required String name,
    int? expiryDays,
    bool canDownload = true,
    bool canPublish = false,
  }) {
    return post(
      '/admin/tokens',
      body: {
        'name': name,
        if (expiryDays != null) 'expiry_days': expiryDays,
        'can_download': canDownload,
        'can_publish': canPublish,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listTokens({
    bool includeAll = false,
  }) async {
    final response = await get(
      '/admin/tokens/me',
      queryParameters: {'all': includeAll ? '1' : '0'},
    );
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> revokeToken(String tokenId) async {
    await post('/admin/tokens/$tokenId/revoke', body: const {});
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final response = await get('/admin/users');
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> disableUser(String userId) async {
    await post('/admin/users/$userId/disable', body: const {});
  }

  void close() {
    _client.close();
  }

  Uri _resolveUri(String path, {Map<String, String>? queryParameters}) {
    return _baseUri.resolveUri(
      Uri(
        path: path,
        queryParameters: queryParameters?.isEmpty == true
            ? null
            : queryParameters,
      ),
    );
  }

  static Uri _normalizeBaseUri(String? baseUrl) {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return Uri.base;
    }
    final parsed = Uri.parse(baseUrl.trim());
    if (!parsed.path.endsWith('/')) {
      return parsed.replace(path: '${parsed.path}/');
    }
    return parsed;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      final error = payload['error'];
      if (error is Map && error['message'] != null) {
        throw error['message'].toString();
      }
      throw 'Request failed (${response.statusCode})';
    }

    final responseError = payload['error'];
    if (responseError != null) {
      throw responseError.toString();
    }
    return payload;
  }
}
