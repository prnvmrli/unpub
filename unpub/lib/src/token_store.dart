abstract class TokenStore {
  Future<bool> isValidToken(String token);

  Future<void> markTokenUsed(String token);

  Future<void> logDownload({
    required String token,
    required String packageName,
    required String version,
    required String? ipAddress,
  });

  Future<ApiKeyRecord> createToken({
    required String ownerName,
    String? expiresAt,
  });

  Future<List<ApiKeyRecord>> listTokens({String? ownerName});

  Future<bool> revokeToken({required int id, String? ownerName});

  Future<List<DownloadRecord>> listDownloads({String? ownerName, int limit});
}

class ApiKeyRecord {
  final int id;
  final String token;
  final String ownerName;
  final String status;
  final String createdAt;
  final String? expiresAt;
  final String? lastUsedAt;

  ApiKeyRecord({
    required this.id,
    required this.token,
    required this.ownerName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'owner_name': ownerName,
    'status': status,
    'created_at': createdAt,
    'expires_at': expiresAt,
    'last_used_at': lastUsedAt,
  };
}

class DownloadRecord {
  final int id;
  final String token;
  final String packageName;
  final String version;
  final String timestamp;
  final String? ipAddress;

  DownloadRecord({
    required this.id,
    required this.token,
    required this.packageName,
    required this.version,
    required this.timestamp,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'package': packageName,
    'version': version,
    'timestamp': timestamp,
    'ip_address': ipAddress,
  };
}
