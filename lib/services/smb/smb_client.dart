import 'smb_entry.dart';
import '../../models/smb_connection.dart';

/// SMB 客户端抽象。不同平台有不同实现：
/// - Android：通过 MethodChannel 调用 jcifs-ng（原生）
/// - 桌面/Web 演示：本地目录 / 虚拟数据
abstract class SmbClient {
  /// 建立连接并校验凭据
  Future<bool> connect(SmbConnection conn);

  /// 列出某路径下的条目（不含父目录）
  Future<List<SmbEntry>> listDir(String path);

  /// 将远程文件下载到本地缓存，返回本地路径（供播放引擎读取）
  /// 对 DSD 而言，原生引擎可直接用此本地路径做比特完美输出
  Future<String> downloadToCache(String path, {void Function(double)? onProgress});

  /// 断开
  Future<void> disconnect();

  void dispose();
}
