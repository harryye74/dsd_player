import 'package:flutter/services.dart';

/// DSD 播放状态
enum DsdState { idle, buffering, playing, paused, stopped, error }

/// 原生 DSD 引擎回传的播放状态
class DsdPlaybackState {
  final DsdState state;
  final Duration position;
  final String? dsdMode; // 如 "DSD64 DoP" / "Native DSD" / "PCM fallback"
  final String? message;
  const DsdPlaybackState(
      {this.state = DsdState.idle,
      this.position = Duration.zero,
      this.dsdMode,
      this.message});
}

/// 与 Android 原生 AAudio DSD 引擎通信（比特完美直出 USB DAC）。
/// 非 Android 环境下所有方法安全降级（返回 false / 抛错由上层捕获）。
class DsdNativeEngine {
  static const _method = MethodChannel('com.audiophile.dsd_player/dsd');
  static const _event = EventChannel('com.audiophile.dsd_player/dsd/state');

  /// 当前设备/引擎是否支持原生 DSD 直出
  Future<bool> isSupported() async {
    try {
      return await _method.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 载入本地 DSD 文件并准备输出
  /// [bitPerfect] 是否尝试独占/比特完美模式
  /// [doP] 是否用 DoP 封装（否则尝试原生 DSD 直出）
  Future<void> load(String localPath,
      {bool bitPerfect = true, bool doP = true}) async {
    await _method.invokeMethod('load', {
      'path': localPath,
      'bitPerfect': bitPerfect,
      'doP': doP,
    });
  }

  Future<void> play() => _method.invokeMethod('play');
  Future<void> pause() => _method.invokeMethod('pause');
  Future<void> stop() => _method.invokeMethod('stop');
  Future<void> seek(Duration d) =>
      _method.invokeMethod('seek', {'ms': d.inMilliseconds});
  Future<void> setVolume(double v) =>
      _method.invokeMethod('setVolume', {'volume': v});

  /// 监听原生引擎回传的状态（位置、DSD 模式等）
  Stream<DsdPlaybackState> get stateStream {
    return _event.receiveBroadcastStream().map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return DsdPlaybackState(
        state: DsdState.values[m['state'] ?? 0],
        position: Duration(milliseconds: m['positionMs'] ?? 0),
        dsdMode: m['dsdMode'],
        message: m['message'],
      );
    });
  }
}
