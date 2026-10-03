/// 音频编码格式枚举
enum AudioCodec {
  flac,
  alac,
  wav,
  ape,
  dsdDsf, // DSF 容器
  dsdDff, // DSDIFF / DFF 容器
  mp3,
  aac,
  other,
}

/// 音频来源类型
enum SourceType {
  smb, // SMB 网盘
  local, // 本机文件
  demo, // 演示数据源
}

extension AudioCodecX on AudioCodec {
  String get label {
    switch (this) {
      case AudioCodec.flac:
        return 'FLAC';
      case AudioCodec.alac:
        return 'ALAC';
      case AudioCodec.wav:
        return 'WAV';
      case AudioCodec.ape:
        return 'APE';
      case AudioCodec.dsdDsf:
      case AudioCodec.dsdDff:
        return 'DSD';
      case AudioCodec.mp3:
        return 'MP3';
      case AudioCodec.aac:
        return 'AAC';
      case AudioCodec.other:
        return 'UNK';
    }
  }

  bool get isLossless {
    return [
      AudioCodec.flac,
      AudioCodec.alac,
      AudioCodec.wav,
      AudioCodec.ape,
    ].contains(this);
  }

  bool get isDsd {
    return this == AudioCodec.dsdDsf || this == AudioCodec.dsdDff;
  }
}

/// DSD 倍速（采样率标识）
/// DSD64 = 2.8224 MHz, DSD128 = 5.6448 MHz, DSD256 = 11.2896 MHz
class DsdRate {
  static const int dsd64 = 2822400;
  static const int dsd128 = 5644800;
  static const int dsd256 = 11289600;

  static String label(int? rateHz) {
    if (rateHz == null) return 'DSD';
    if (rateHz >= dsd256) return 'DSD256';
    if (rateHz >= dsd128) return 'DSD128';
    return 'DSD64';
  }
}
