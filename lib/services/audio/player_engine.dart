import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dsd_native.dart';
import '../../models/track.dart';
import '../../models/audio_format.dart';
import '../../util/platform.dart';

/// 统一播放引擎：
/// - 无损（FLAC/ALAC/WAV/APE/MP3）：just_audio
/// - DSD（.dsf/.dff）：Android 上经原生 AAudio 引擎做比特完美直出；
///   桌面/Web 或不支持时降级为 PCM 回退（仅用于演示 UI）
class PlayerEngine with ChangeNotifier {
  final AudioPlayer _lossless = AudioPlayer();
  final DsdNativeEngine _dsd = DsdNativeEngine();

  List<Track> _queue = [];
  int _index = -1;
  Track? _current;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isDsd = false;
  bool _usingNativeDsd = false;
  bool _bitPerfect = false;
  String? _dsdMode;
  String? _error;
  bool _buffering = false;

  late final StreamSubscription _posSub;
  late final StreamSubscription _durSub;
  late final StreamSubscription _stateSub;
  late final StreamSubscription _dsdSub;

  PlayerEngine() {
    _posSub = _lossless.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durSub = _lossless.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _stateSub = _lossless.playerStateStream.listen((s) {
      _isPlaying = s.playing;
      _buffering = s.processingState == ProcessingState.buffering ||
          s.processingState == ProcessingState.loading;
      if (s.processingState == ProcessingState.completed) _onCompleted();
      notifyListeners();
    });
    // 原生 DSD 状态回传（非 Android 下订阅会失败，已忽略）
    if (isAndroidPlatform) {
      _dsdSub = _dsd.stateStream.listen((st) {
        _position = st.position;
        _isPlaying = st.state == DsdState.playing;
        if (st.dsdMode != null) _dsdMode = st.dsdMode;
        if (st.message != null) _error = st.message;
        notifyListeners();
      }, onError: (_) {});
    } else {
      _dsdSub = const Stream.empty().listen((_) {});
    }
  }

  // ---- getters ----
  List<Track> get queue => List.unmodifiable(_queue);
  int get index => _index;
  Track? get current => _current;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isDsd => _isDsd;
  bool get bitPerfect => _bitPerfect;
  String? get dsdMode => _dsdMode;
  String? get error => _error;
  bool get buffering => _buffering;
  bool get hasNext => _index >= 0 && _index < _queue.length - 1;
  bool get hasPrev => _index > 0;

  // ---- 队列控制 ----
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue = List.from(tracks);
    _index = startIndex.clamp(0, tracks.length - 1);
    await _playCurrent();
  }

  Future<void> addToQueue(List<Track> tracks) async {
    _queue.addAll(tracks);
    notifyListeners();
  }

  Future<void> _playCurrent() async {
    if (_index < 0 || _index >= _queue.length) return;
    final t = _queue[_index];
    _current = t;
    _error = null;
    _isDsd = false;
    _usingNativeDsd = false;
    _bitPerfect = false;
    _dsdMode = null;
    notifyListeners();

    if (t.codec.isDsd) {
      await _playDsd(t);
    } else {
      await _playLossless(t);
    }
  }

  Future<void> _playLossless(Track t) async {
    _isDsd = false;
    _dsdMode = null;
    try {
      await _lossless.stop();
      await _lossless.setFilePath(t.uri);
      _duration = _lossless.duration ?? Duration.zero;
      await _lossless.play();
    } catch (e) {
      _error = '播放失败：$e';
    }
    notifyListeners();
  }

  Future<void> _playDsd(Track t) async {
    // 期望 t.uri 已是本地缓存路径（SMB 场景已 downloadToCache）
    if (isAndroidPlatform) {
      try {
        final supported = await _dsd.isSupported();
        if (supported) {
          await _dsd.load(t.uri, bitPerfect: true, doP: true);
          await _dsd.play();
          _isDsd = true;
          _usingNativeDsd = true;
          _bitPerfect = true;
          _dsdMode = 'DSD 比特完美（DoP / Native 直出 USB DAC）';
          _duration = t.duration ?? Duration.zero;
          notifyListeners();
          return;
        }
      } catch (e) {
        _error = 'DSD 原生引擎失败：$e';
      }
    }
    // 回退：桌面 / Web / 不支持 —— 标记 PCM 回退（真机请用 Android + USB DAC）
    _isDsd = true;
    _usingNativeDsd = false;
    _bitPerfect = false;
    _dsdMode = 'PCM 回退（演示环境，非比特完美）';
    try {
      await _lossless.stop();
      await _lossless.setFilePath(t.uri);
      await _lossless.play();
    } catch (e) {
      _error = 'DSD 演示回退失败（真机请部署到 Android + USB DAC）：$e';
    }
    notifyListeners();
  }

  // ---- 播放控制 ----
  Future<void> togglePlay() async {
    if (_current == null) return;
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    if (_usingNativeDsd) {
      await _dsd.pause();
    } else {
      await _lossless.pause();
    }
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_current == null) return;
    if (_usingNativeDsd) {
      await _dsd.play();
    } else {
      await _lossless.play();
    }
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    if (_usingNativeDsd) {
      await _dsd.stop();
    } else {
      await _lossless.stop();
    }
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> next() async {
    if (hasNext) {
      _index++;
      await _playCurrent();
    }
  }

  Future<void> prev() async {
    if (_position > const Duration(seconds: 3) && _current != null) {
      await seek(Duration.zero);
      return;
    }
    if (hasPrev) {
      _index--;
      await _playCurrent();
    }
  }

  Future<void> seek(Duration d) async {
    _position = d;
    if (_usingNativeDsd) {
      await _dsd.seek(d);
    } else {
      await _lossless.seek(d);
    }
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    if (_usingNativeDsd) {
      await _dsd.setVolume(v);
    } else {
      await _lossless.setVolume(v);
    }
  }

  void _onCompleted() {
    if (hasNext) {
      next();
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _dsdSub.cancel();
    _lossless.dispose();
    super.dispose();
  }
}
