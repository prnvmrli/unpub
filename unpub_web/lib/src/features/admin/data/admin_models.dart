class AdminToken {
  AdminToken({
    required this.id,
    required this.token,
    required this.ownerName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  final int id;
  final String token;
  final String ownerName;
  final String status;
  final String? createdAt;
  final String? expiresAt;
  final String? lastUsedAt;

  factory AdminToken.fromJson(Map<String, dynamic> json) {
    return AdminToken(
      id: (json['id'] as num?)?.toInt() ?? 0,
      token: '${json['token'] ?? ''}',
      ownerName: '${json['owner_name'] ?? ''}',
      status: '${json['status'] ?? ''}',
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

