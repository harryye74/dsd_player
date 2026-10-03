import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'smb_channel.dart';
import 'smb_client.dart';
import 'local_demo_factory.dart';
import '../../models/smb_connection.dart';
import '../../util/platform.dart';

/// 管理 SMB 连接配置，并负责为当前浏览打开合适的客户端。
class SmbManager with ChangeNotifier {
  static const _kStoreKey = 'smb.connections';

  final List<SmbConnection> _connections = [];
  SmbClient? _activeClient;
  SmbConnection? _activeConnection;
  bool _isLocalDemo = false;

  List<SmbConnection> get connections => List.unmodifiable(_connections);
  SmbClient? get activeClient => _activeClient;
  SmbConnection? get activeConnection => _activeConnection;
  bool get isLocalDemo => _isLocalDemo;
  bool get hasActive => _activeClient != null;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStoreKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _connections
            .addAll(list.map((e) => SmbConnection.fromJson(e)).toList());
        notifyListeners();
      }
    } catch (_) {
      // 忽略存储读取异常，使用空列表
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kStoreKey, jsonEncode(_connections.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> upsert(SmbConnection c) async {
    final idx = _connections.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      _connections[idx] = c;
    } else {
      _connections.add(c);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _connections.removeWhere((x) => x.id == id);
    if (_activeConnection?.id == id) await closeActive();
    await _persist();
    notifyListeners();
  }

  /// 在 Android 真机上打开一个真实 SMB 连接（jcifs-ng）
  Future<void> openSmb(SmbConnection c) async {
    if (!isAndroidPlatform) {
      throw SmbException('当前为桌面/Web 演示环境，SMB 原生桥不可用。'
          '请选择"本地演示目录"，或在 Android 真机上运行。');
    }
    final client = SmbChannelClient();
    final ok = await client.connect(c);
    if (!ok) throw SmbException('SMB 连接失败，请检查地址 / 共享名 / 账号密码');
    _activeClient = client;
    _activeConnection = c;
    _isLocalDemo = false;
    notifyListeners();
  }

  /// 桌面/Web 演示：把本地目录（路径字符串）当作共享来浏览
  Future<void> openLocal(String dirPath) async {
    _activeClient = createLocalDemoClient(dirPath);
    _activeConnection = null;
    _isLocalDemo = true;
    notifyListeners();
  }

  Future<void> closeActive() async {
    await _activeClient?.disconnect();
    _activeClient = null;
    _activeConnection = null;
    _isLocalDemo = false;
    notifyListeners();
  }
}
