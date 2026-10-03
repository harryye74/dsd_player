import 'package:flutter/services.dart';
import 'smb_client.dart';
import 'smb_entry.dart';
import '../../models/smb_connection.dart';

/// Android 端通过 jcifs-ng 实现的 SMB 客户端。
/// 由 MainActivity 中注册的 MethodChannel 处理：
///   smb.connect / smb.list / smb.download
class SmbChannelClient implements SmbClient {
  static const _channel = MethodChannel('com.audiophile.dsd_player/smb');

  SmbConnection? _active;

  @override
  Future<bool> connect(SmbConnection conn) async {
    try {
      final ok = await _channel.invokeMethod<bool>('connect', conn.toJson());
      if (ok == true) _active = conn;
      return ok == true;
    } on PlatformException catch (e) {
      throw SmbException('连接失败：${e.message}');
    }
  }

  @override
  Future<List<SmbEntry>> listDir(String path) async {
    if (_active == null) throw SmbException('尚未连接');
    final raw = await _channel.invokeMethod<List<dynamic>>('list', {
      'connection': _active!.toJson(),
      'path': path,
    });
    return (raw ?? [])
        .map((e) => _entryFromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<String> downloadToCache(String path,
      {void Function(double)? onProgress}) async {
    if (_active == null) throw SmbException('尚未连接');
    final local = await _channel.invokeMethod<String>('download', {
      'connection': _active!.toJson(),
      'path': path,
    });
    if (local == null) throw SmbException('下载失败');
    return local;
  }

  @override
  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
    _active = null;
  }

  @override
  void dispose() => disconnect();

  SmbEntry _entryFromMap(Map<String, dynamic> m) => SmbEntry(
        name: m['name'],
        path: m['path'],
        isDirectory: m['isDirectory'] == true,
        sizeBytes: m['sizeBytes'],
        lastModified: m['lastModified'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['lastModified'])
            : null,
      );
}

/// 便捷异常
class SmbException implements Exception {
  final String message;
  SmbException(this.message);
  @override
  String toString() => message;
}
