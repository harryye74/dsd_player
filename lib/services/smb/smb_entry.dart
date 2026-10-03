/// SMB 共享中的一个条目（文件或目录）
class SmbEntry {
  final String name;
  final String path; // 共享内绝对路径，如 /Music/album
  final bool isDirectory;
  final int? sizeBytes;
  final DateTime? lastModified;

  const SmbEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes,
    this.lastModified,
  });

  /// 是否为可播放的音频文件（按扩展名粗筛）
  bool get isAudioFile {
    if (isDirectory) return false;
    final ext = name.toLowerCase().split('.').last;
    return [
      'flac',
      'alac',
      'wav',
      'ape',
      'dsf',
      'dff',
      'mp3',
      'aac',
      'm4a',
      'ogg'
    ].contains(ext);
  }

  static String extensionOf(String name) =>
      name.contains('.') ? name.toLowerCase().split('.').last : '';
}
