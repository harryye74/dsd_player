import 'dart:io';

bool get isAndroidPlatform => Platform.isAndroid;
bool get isIOSPlatform => Platform.isIOS;
bool get isDesktopPlatform =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;
