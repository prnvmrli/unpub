import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._apiClient);

  final ApiClient _apiClient;
  String? _token;

  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  String get shortToken {
    if (!isLoggedIn) return 'none';
    final value = _token!;
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  Future<bool> login(String token) async {
    try {
      await _apiClient.get(
        '/admin/tokens/me',
        headers: {'authorization': 'Bearer $token'},
      );
      _token = token;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void logout() {
    _token = null;
    notifyListeners();
  }
}
