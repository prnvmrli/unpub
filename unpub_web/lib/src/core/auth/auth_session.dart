import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._apiClient);

  final ApiClient _apiClient;
  bool _loading = false;
  String? _ownerName;

  bool get isLoading => _loading;
  String? get ownerName => _ownerName;
  bool get isLoggedIn => _ownerName != null && _ownerName!.isNotEmpty;
  String get shortToken => isLoggedIn ? _ownerName! : 'none';

  Future<void> restoreSession() async {
    _loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.get('/auth/me');
      final data = response['data'] as Map<String, dynamic>;
      _ownerName = data['owner_name']?.toString();
    } catch (_) {
      _ownerName = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String token) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        headers: const {'content-type': 'application/json'},
        body: {'token': token},
      );
      final data = response['data'] as Map<String, dynamic>;
      _ownerName = data['owner_name']?.toString();
      notifyListeners();
      return isLoggedIn;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(
        '/auth/logout',
        headers: const {'content-type': 'application/json'},
        body: const {},
      );
    } catch (_) {
      // ignore
    }
    _ownerName = null;
    notifyListeners();
  }
}

