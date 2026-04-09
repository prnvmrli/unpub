abstract class TokenStore {
  Future<UserRecord?> authenticateUser({
    required String email,
    required String password,
  });

  Future<UserRecord?> findUserByEmail(String email);

  Future<List<UserRecord>> listUsers();

  Future<bool> disableUser(int userId);

  Future<UserRecord> createUser({
    required String email,
    required String password,
    required String role,
  });

  Future<TokenValidationRecord?> validateToken(String token);

  Future<bool> isValidToken(String token);

  Future<void> markTokenUsed({required int tokenId});

  Future<void> logDownload({
    required int tokenId,
    required int userId,
    required String packageName,
    required String version,
    required String? ipAddress,
  });

  Future<ApiKeyRecord> createToken({
    required String ownerName,
    required String name,
    String? expiresAt,
    bool canDownload = true,
    bool canPublish = false,
  });

  Future<List<ApiKeyRecord>> listTokens({String? ownerName});

  Future<bool> revokeToken({required int id, String? ownerName});

  Future<List<DownloadRecord>> listDownloads({String? ownerName, int limit});

  Future<String?> ownerByToken(String token);
}

class UserRecord {
  final int id;
  final String email;
  final String role;
  final bool isDisabled;
  final String? disabledAt;
  final String createdAt;
  final String updatedAt;

  const UserRecord({
    required this.id,
    required this.email,
    required this.role,
    required this.isDisabled,
    required this.disabledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'is_disabled': isDisabled,
    'disabled_at': disabledAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class TokenValidationRecord {
  final int tokenId;
  final int userId;
  final String ownerName;
  final bool canDownload;
  final bool canPublish;

  const TokenValidationRecord({
    required this.tokenId,
    required this.userId,
    required this.ownerName,
    required this.canDownload,
    required this.canPublish,
  });
}

class ApiKeyRecord {
  final int id;
  final String name;
  final String token;
  final int userId;
  final String ownerName;
  final String status;
  final bool canDownload;
  final bool canPublish;
  final bool revoked;
  final String createdAt;
  final String? expiresAt;
  final String? lastUsedAt;

  ApiKeyRecord({
    required this.id,
    required this.name,
    required this.token,
    required this.userId,
    required this.ownerName,
    required this.status,
    required this.canDownload,
    required this.canPublish,
    required this.revoked,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'token': token,
    'user_id': userId,
    'owner_name': ownerName,
    'status': status,
    'can_download': canDownload,
    'can_publish': canPublish,
    'revoked': revoked,
    'created_at': createdAt,
    'expires_at': expiresAt,
    'last_used_at': lastUsedAt,
  };
}

class DownloadRecord {
  final int id;
  final int tokenId;
  final int? userId;
  final String tokenPrefix;
  final String packageName;
  final String version;
  final String timestamp;
  final String? ipAddress;

  DownloadRecord({
    required this.id,
    required this.tokenId,
    required this.userId,
    required this.tokenPrefix,
    required this.packageName,
    required this.version,
    required this.timestamp,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'token_id': tokenId,
    'user_id': userId,
    'token': tokenPrefix,
    'package': packageName,
    'version': version,
    'timestamp': timestamp,
    'ip_address': ipAddress,
  };
}
