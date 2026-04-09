import '../../../core/network/api_client.dart';
import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AdminToken>> listTokens({bool includeAll = false}) async {
    final data = await _apiClient.listTokens(includeAll: includeAll);
    return data.map(AdminToken.fromJson).toList(growable: false);
  }

  Future<String> createToken({
    required String name,
    int? expiryDays,
    bool canDownload = true,
    bool canPublish = false,
  }) async {
    final response = await _apiClient.createToken(
      name: name,
      expiryDays: expiryDays,
      canDownload: canDownload,
      canPublish: canPublish,
    );
    final data = response['data'] as Map<String, dynamic>;
    return '${data['token'] ?? ''}';
  }

  Future<void> revokeToken({required String tokenId}) async {
    await _apiClient.revokeToken(tokenId);
  }

  Future<List<AdminUser>> listUsers() async {
    final data = await _apiClient.listUsers();
    return data.map(AdminUser.fromJson).toList(growable: false);
  }

  Future<void> disableUser({required String userId}) async {
    await _apiClient.disableUser(userId);
  }

  Future<List<DownloadLog>> listDownloads({
    bool includeAll = false,
    int limit = 100,
  }) async {
    final response = await _apiClient.get(
      '/admin/downloads',
      queryParameters: {'all': includeAll ? '1' : '0', 'limit': '$limit'},
    );
    final data = (response['data'] as List).cast<Map<String, dynamic>>();
    return data.map(DownloadLog.fromJson).toList(growable: false);
  }
}
