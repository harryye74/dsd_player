// 条件导入：Web 下 dart:io 不可用，统一从这里取平台判断
export 'platform_io.dart' if (dart.library.html) 'platform_web.dart';

import 'package:flutter/foundation.dart';

bool get isWeb => kIsWeb;
