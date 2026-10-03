import 'dart:io';
import 'smb_client.dart';
import 'smb_entry.dart';
import '../../models/smb_connection.dart';

/// 桌面/Web 演示用：把"本地某个目录"当作 SMB 共享来浏览。
/// 文件本身已在本地，downloadToCache 直接返回其绝对路径。
/// 这样原型在 Linux/Chrome 上也能真实浏览并播放本地无损音乐。
class SmbLocalDemoClient implements SmbClient {
  final Directory root;

  SmbLocalDemoClient(this.root);

  @override
  Future<bool> connect(SmbConnection conn) async {
    return root.existsSync();
  }

  @override
  Future<List<SmbEntry>> listDir(String path) async {
    final dir = Directory(_resolve(path));
    if (!await dir.exists()) return const [];
    final entities = dir.listSync().whereType<FileSystemEntity>().toList();
    final entries = <SmbEntry>[];
    for (final e in entities) {
      final stat = e.statSync();
      final name = e.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      final isDir = stat.type == FileSystemEntityType.directory;
      entries.add(SmbEntry(
        name: name,
        path: '$path/$name'.replaceAll('//', '/'),
        isDirectory: isDir,
        sizeBytes: isDir ? null : stat.size,
        lastModified: stat.modified,
      ));
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<String> downloadToCache(String path,
      {void Function(double)? onProgress}) async {
    return _resolve(path);
  }

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {}

  String _resolve(String path) {
    if (path == '/' || path.isEmpty) return root.path;
    return '${root.path}${path.startsWith('/') ? path : '/$path'}';
  }
}

/// 由本地目录路径构造演示用 SMB 客户端（仅非 Web 平台）
SmbClient createLocalDemoClient(String path) => SmbLocalDemoClient(Directory(path));
