/// SMB 网盘连接配置
class SmbConnection {
  final String id;
  final String name; // 用户自定义名称，如 "家庭 NAS"
  final String host; // IP 或域名，如 192.168.1.100
  final int port; // SMB 端口，默认 445
  final String share; // 共享名，如 Music
  final String? domain; // 工作组/域，可选
  final String username;
  final String password;

  const SmbConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 445,
    required this.share,
    this.domain,
    required this.username,
    required this.password,
  });

  /// 形如 smb://host:port/share 的根路径
  String get rootPath => '/';

  /// 拼接完整 SMB URL（jcifs 使用）
  String toJcifsUrl(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    final dom = domain != null && domain!.isNotEmpty ? '$domain;' : '';
    return 'smb://$dom$username:$password@$host:$port/$share$p';
  }

  SmbConnection copyWith({
    String? name,
    String? host,
    int? port,
    String? share,
    String? domain,
    String? username,
    String? password,
  }) =>
      SmbConnection(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        share: share ?? this.share,
        domain: domain ?? this.domain,
        username: username ?? this.username,
        password: password ?? this.password,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'share': share,
        'domain': domain,
        'username': username,
        'password': password,
      };

  factory SmbConnection.fromJson(Map<String, dynamic> m) => SmbConnection(
        id: m['id'],
        name: m['name'],
        host: m['host'],
        port: m['port'] ?? 445,
        share: m['share'],
        domain: m['domain'],
        username: m['username'],
        password: m['password'],
      );
}
