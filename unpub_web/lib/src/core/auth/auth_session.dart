import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._apiClient);

  final ApiClient _apiClient;
  bool _loading = false;
  String? _ownerName;
  String? _userRole;

  bool get isLoading => _loading;
  String? get ownerName => _ownerName;
  String? get userRole => _userRole;
  bool get isAdmin => _userRole == 'admin';
  bool get isLoggedIn => _ownerName != null && _ownerName!.isNotEmpty;
  String get shortToken => isLoggedIn ? _ownerName! : 'none';

  Future<void> restoreSession() async {
    _loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.getCurrentUser();
      _applySessionData(response['data'] as Map<String, dynamic>);
    } catch (_) {
      _ownerName = null;
      _userRole = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.login(email: email, password: password);
      _applySessionData(response['data'] as Map<String, dynamic>);
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
    _userRole = null;
    notifyListeners();
  }

  void _applySessionData(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      final email = user['email']?.toString().trim();
      final role = user['role']?.toString().trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        _ownerName = email;
        _userRole = (role == null || role.isEmpty) ? 'client' : role;
        return;
      }
    }
    final owner = data['owner_name']?.toString().trim();
    _ownerName = (owner == null || owner.isEmpty) ? null : owner;
    _userRole = _ownerName == null ? null : 'developer';
  }
}
