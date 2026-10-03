import 'audio_format.dart';

/// 一首曲目（无论来自 SMB、本机还是演示源）
class Track {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final AudioCodec codec;
  final SourceType sourceType;

  /// 播放/读取用的实际路径或 URI。
  /// - SMB：经原生桥下载到缓存后的本地路径，或 SMB 直链
  /// - local/demo：本地路径或虚拟 URI
  final String uri;

  /// 用于浏览展示的路径（SMB 共享内的路径，如 /Music/album/track.flac）
  final String displayPath;

  final int? sampleRate; // Hz，如 44100 / 96000 / 192000
  final int? channels; // 1=单声道 2=立体声
  final int? bitsPerSample; // 位深，如 16/24
  final int? dsdRate; // DSD 倍速对应的采样率（2.8224M 等）
  final Duration? duration;
  final int? sizeBytes;

  const Track({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    required this.codec,
    required this.sourceType,
    required this.uri,
    required this.displayPath,
    this.sampleRate,
    this.channels,
    this.bitsPerSample,
    this.dsdRate,
    this.duration,
    this.sizeBytes,
  });

  /// 是否在 Android 上走原生 DSD 比特完美引擎
  bool get needsNativeDsd => codec.isDsd;

  /// 用于 Now Playing 显示的格式徽章文本
  String get formatBadge {
    if (codec.isDsd) {
      return DsdRate.label(dsdRate);
    }
    final rate = sampleRate != null ? '${sampleRate! ~/ 1000}k' : '';
    final bits = bitsPerSample != null ? '/${bitsPerSample}bit' : '';
    final ch = channels == 1 ? ' Mono' : channels == 2 ? ' Stereo' : '';
    return '${codec.label} $rate$bits$ch'.trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'codec': codec.name,
        'sourceType': sourceType.name,
        'uri': uri,
        'displayPath': displayPath,
        'sampleRate': sampleRate,
        'channels': channels,
        'bitsPerSample': bitsPerSample,
        'dsdRate': dsdRate,
        'durationMs': duration?.inMilliseconds,
        'sizeBytes': sizeBytes,
      };

  factory Track.fromJson(Map<String, dynamic> m) => Track(
        id: m['id'],
        title: m['title'],
        artist: m['artist'],
        album: m['album'],
        codec: AudioCodec.values.byName(m['codec']),
        sourceType: SourceType.values.byName(m['sourceType']),
        uri: m['uri'],
        displayPath: m['displayPath'],
        sampleRate: m['sampleRate'],
        channels: m['channels'],
        bitsPerSample: m['bitsPerSample'],
        dsdRate: m['dsdRate'],
        duration: m['durationMs'] != null
            ? Duration(milliseconds: m['durationMs'])
            : null,
        sizeBytes: m['sizeBytes'],
      );
}
