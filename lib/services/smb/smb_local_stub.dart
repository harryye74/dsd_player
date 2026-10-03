import 'smb_client.dart';

/// Web 平台占位：本地目录演示依赖 dart:io，Web 不支持。
/// 函数签名与 smb_local_demo.dart 中的工厂保持一致，便于条件导入。
SmbClient createLocalDemoClient(String path) {
  throw UnsupportedError('本地目录演示仅在 Android / 桌面支持，Web 不可用');
}
