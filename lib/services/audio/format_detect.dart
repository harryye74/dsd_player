import '../../models/audio_format.dart';

/// 解析结果
class DetectedFormat {
  final AudioCodec codec;
  final int? sampleRate;
  final int? channels;
  final int? bitsPerSample;
  final int? dsdRate;

  const DetectedFormat({
    required this.codec,
    this.sampleRate,
    this.channels,
    this.bitsPerSample,
    this.dsdRate,
  });
}

/// 根据文件名与可选的文件头字节识别编码格式。
/// - DSD(.dsf/.dff)：尽量解析真实倍速与声道数
/// - 其它无损：按扩展名判定（采样率由播放引擎补充）
DetectedFormat detectFormat(String fileName, {List<int>? headerBytes}) {
  final lower = fileName.toLowerCase();
  final ext = lower.contains('.') ? lower.split('.').last : '';

  switch (ext) {
    case 'dsf':
      return _parseDsf(headerBytes);
    case 'dff':
    case 'dff8':
      // DSDIFF：标记 DSD，倍速默认 DSD64（头部解析较复杂，原型先默认）
      return const DetectedFormat(
          codec: AudioCodec.dsdDff, dsdRate: DsdRate.dsd64);
    case 'flac':
      return const DetectedFormat(codec: AudioCodec.flac);
    case 'alac':
    case 'm4a':
      return const DetectedFormat(codec: AudioCodec.alac);
    case 'wav':
    case 'wave':
      return const DetectedFormat(codec: AudioCodec.wav);
    case 'ape':
      return const DetectedFormat(codec: AudioCodec.ape);
    case 'mp3':
      return const DetectedFormat(codec: AudioCodec.mp3);
    case 'aac':
      return const DetectedFormat(codec: AudioCodec.aac);
    default:
      return const DetectedFormat(codec: AudioCodec.other);
  }
}

/// 解析 DSF 文件头，提取采样率（DSD 倍速）与声道数。
/// 参考 DSF 格式：offset 28 = sampleRate(LE u32)，offset 32 = channels(LE u16)
DetectedFormat _parseDsf(List<int>? bytes) {
  int? dsdRate;
  int? channels;
  if (bytes != null && bytes.length >= 36) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x44 &&
        bytes[1] == 0x53 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x20) {
      // "DSD "
      dsdRate = _readLE32(bytes, 28);
      channels = _readLE16(bytes, 32);
    }
  }
  return DetectedFormat(
    codec: AudioCodec.dsdDsf,
    dsdRate: dsdRate,
    channels: channels,
  );
}

int _readLE32(List<int> b, int off) =>
    (b[off] & 0xff) |
    ((b[off + 1] & 0xff) << 8) |
    ((b[off + 2] & 0xff) << 16) |
    ((b[off + 3] & 0xff) << 24);

int _readLE16(List<int> b, int off) =>
    (b[off] & 0xff) | ((b[off + 1] & 0xff) << 8);
