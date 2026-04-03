import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  const ApiClient();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = Uri(
      path: path,
      queryParameters: queryParameters?.isEmpty == true ? null : queryParameters,
    );
    final response = await http.get(uri, headers: headers);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri(path: path);
    final response = await http.post(uri, headers: headers, body: json.encode(body));
    return _decodeResponse(response);
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
