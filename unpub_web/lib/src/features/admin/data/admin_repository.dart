import '../../../core/network/api_client.dart';
import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Map<String, String> _authHeaders(String token) => {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      };

  Future<List<AdminToken>> listTokens({
    required String token,
    bool includeAll = false,
  }) async {
    final response = await _apiClient.get(
      '/admin/tokens/me',
      queryParameters: {'all': includeAll ? '1' : '0'},
      headers: _authHeaders(token),
    );
    final data = (response['data'] as List).cast<Map<String, dynamic>>();
    return data.map(AdminToken.fromJson).toList(growable: false);
  }

  Future<String> createToken({
    required String token,
    String? ownerName,
    String? expiresAt,
  }) async {
    final response = await _apiClient.post(
      '/admin/tokens',
      headers: _authHeaders(token),
      body: {
        if (ownerName != null && ownerName.trim().isNotEmpty)
          'owner_name': ownerName.trim(),
        if (expiresAt != null && expiresAt.trim().isNotEmpty)
          'expires_at': expiresAt.trim(),
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    return '${data['token'] ?? ''}';
  }

  Future<void> revokeToken({
    required String token,
    required String tokenId,
  }) async {
    await _apiClient.post(
      '/admin/tokens/$tokenId/revoke',
      headers: _authHeaders(token),
      body: const {},
    );
  }

  Future<List<DownloadLog>> listDownloads({
    required String token,
    bool includeAll = false,
    int limit = 100,
  }) async {
    final response = await _apiClient.get(
      '/admin/downloads',
      queryParameters: {
        'all': includeAll ? '1' : '0',
        'limit': '$limit',
      },
      headers: _authHeaders(token),
    );
    final data = (response['data'] as List).cast<Map<String, dynamic>>();
    return data.map(DownloadLog.fromJson).toList(growable: false);
  }
}

