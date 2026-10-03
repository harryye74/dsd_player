import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_format.dart';
import '../models/track.dart';
import '../services/audio/player_engine.dart';
import '../services/audio/track_factory.dart';
import '../services/smb/smb_entry.dart';
import '../services/smb/smb_manager.dart';
import '../ui/widgets/mini_player.dart';
import '../ui/widgets/track_tile.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({Key? key}) : super(key: key);

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final List<String> _pathStack = ['/'];
  List<SmbEntry> _entries = [];
  bool _loading = true;
  String? _error;
  Track? _loadingTrack;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _currentPath => _pathStack.last;

  Future<void> _load() async {
    final smb = context.read<SmbManager>();
    if (smb.activeClient == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await smb.activeClient!.listDir(_currentPath);
      setState(() {
        _entries = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _enterDir(SmbEntry dir) {
    _pathStack.add(dir.path);
    _load();
  }

  void _goUp() {
    if (_pathStack.length > 1) {
      _pathStack.removeLast();
      _load();
    }
  }

  Future<void> _playEntry(SmbEntry entry) async {
    final smb = context.read<SmbManager>();
    final engine = context.read<PlayerEngine>();
    final client = smb.activeClient;
    if (client == null) return;

    setState(() => _loadingTrack = _trackPlaceholder(entry));
    try {
      final local = await client.downloadToCache(entry.path);
      final src = smb.isLocalDemo ? SourceType.local : SourceType.smb;
      final track = buildTrackFromEntry(entry, local, src);
      await engine.playQueue([track]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始播放：${track.title}（${track.formatBadge}）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('播放失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingTrack = null);
    }
  }

  Track _trackPlaceholder(SmbEntry e) => Track(
      id: e.path,
      title: e.name,
      codec: AudioCodec.other,
      sourceType: SourceType.local,
      uri: '',
      displayPath: e.path);

  @override
  Widget build(BuildContext context) {
    final smb = context.watch<SmbManager>();
    final title = smb.activeConnection?.name ??
        (smb.isLocalDemo ? '本地演示目录' : '浏览');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_pathStack.length > 1) {
              _goUp();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white.withOpacity(0.03),
            child: Text(_currentPath,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)))
                    : _entries.isEmpty
                        ? const Center(
                            child: Text('空目录',
                                style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (_, i) {
                              final e = _entries[i];
                              if (e.isDirectory) {
                                return ListTile(
                                  leading: const Icon(Icons.folder,
                                      color: Colors.amber),
                                  title: Text(e.name),
                                  onTap: () => _enterDir(e),
                                );
                              }
                              final isLoading = _loadingTrack?.id == e.path;
                              return TrackTile(
                                track: _loadingTrack != null && isLoading
                                    ? _loadingTrack!
                                    : _placeholderTrack(e),
                                isCurrent: false,
                                onTap: isLoading ? null : () => _playEntry(e),
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _loadingTrack != null
          ? const LinearProgressIndicator()
          : const MiniPlayer(),
    );
  }

  Track _placeholderTrack(SmbEntry e) => Track(
        id: e.path,
        title: e.name,
        codec: AudioCodec.other,
        sourceType: SourceType.local,
        uri: '',
        displayPath: e.path,
      );
}
