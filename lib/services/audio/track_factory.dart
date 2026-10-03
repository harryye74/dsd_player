import 'format_detect.dart';
import '../../models/track.dart';
import '../../models/audio_format.dart';
import '../smb/smb_entry.dart';

/// 由 SMB/本地条目与已下载到本地的路径构造 Track。
/// DSD 的真实倍速 / 声道数在 Android 上由原生引擎解析头信息后通过状态回传；
/// 此处按扩展名给出默认值，足够用于徽章展示与播放决策。
Track buildTrackFromEntry(SmbEntry e, String localUri, SourceType src) {
  final fmt = detectFormat(e.name);
  return Track(
    id: '${src.name}:${e.path}',
    title: e.name,
    codec: fmt.codec,
    sourceType: src,
    uri: localUri,
    displayPath: e.path,
    sampleRate: fmt.sampleRate,
    channels: fmt.channels,
    bitsPerSample: fmt.bitsPerSample,
    dsdRate: fmt.dsdRate,
    sizeBytes: e.sizeBytes,
  );
}
