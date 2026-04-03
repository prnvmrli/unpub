import 'package:unpub_api/models.dart';

import '../../../core/network/api_client.dart';

class PackagesRepository {
  PackagesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ListApi> fetchPackages({
    int size = 10,
    int page = 0,
    String? query,
  }) async {
    final response = await _apiClient.get(
      '/webapi/packages',
      queryParameters: {
        'size': '$size',
        'page': '$page',
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return ListApi.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<WebapiDetailView> fetchPackage(String name, String version) async {
    final response = await _apiClient.get('/webapi/package/$name/$version');
    return WebapiDetailView.fromJson(response['data'] as Map<String, dynamic>);
  }
}

