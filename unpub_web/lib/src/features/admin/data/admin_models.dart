class AdminToken {
  AdminToken({
    required this.id,
    required this.name,
    required this.token,
    required this.ownerName,
    required this.status,
    required this.canDownload,
    required this.canPublish,
    required this.revoked,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  final int id;
  final String name;
  final String token;
  final String ownerName;
  final String status;
  final bool canDownload;
  final bool canPublish;
  final bool revoked;
  final String? createdAt;
  final String? expiresAt;
  final String? lastUsedAt;

  factory AdminToken.fromJson(Map<String, dynamic> json) {
    return AdminToken(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: '${json['name'] ?? ''}',
      token: '${json['token'] ?? ''}',
      ownerName: '${json['owner_name'] ?? ''}',
      status: '${json['status'] ?? ''}',
      canDownload: json['can_download'] == true,
      canPublish: json['can_publish'] == true,
      revoked: json['revoked'] == true,
      createdAt: json['created_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      lastUsedAt: json['last_used_at']?.toString(),
    );
  }
}

class DownloadLog {
  DownloadLog({
    required this.id,
    required this.token,
    required this.packageName,
    required this.version,
    required this.timestamp,
    required this.ipAddress,
  });

  final int id;
  final String token;
  final String packageName;
  final String version;
  final String timestamp;
  final String? ipAddress;

  factory DownloadLog.fromJson(Map<String, dynamic> json) {
    return DownloadLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      token: '${json['token'] ?? ''}',
      packageName: '${json['package'] ?? ''}',
      version: '${json['version'] ?? ''}',
      timestamp: '${json['timestamp'] ?? ''}',
      ipAddress: json['ip_address']?.toString(),
    );
  }
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.email,
    required this.role,
    required this.isDisabled,
  });

  final int id;
  final String email;
  final String role;
  final bool isDisabled;

  String get status => isDisabled ? 'disabled' : 'active';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: '${json['email'] ?? ''}',
      role: '${json['role'] ?? ''}',
      isDisabled: json['is_disabled'] == true,
    );
  }
}
