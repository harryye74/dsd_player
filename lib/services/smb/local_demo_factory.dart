// 条件导入：Web 下 dart:io 不可用，改用占位实现。
export 'smb_local_demo.dart' if (dart.library.html) 'smb_local_stub.dart';
