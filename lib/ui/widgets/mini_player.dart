import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/audio_format.dart';
import '../../services/audio/player_engine.dart';
import '../now_playing_page.dart';

/// 全局底部迷你播放条，点击进入 Now Playing
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<PlayerEngine>();
    if (engine.current == null) return const SizedBox.shrink();

    final track = engine.current!;
    return SafeArea(
      child: Material(
        color: const Color(0xFF1c1c22),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NowPlayingPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Icon(track.codec.isDsd ? Icons.graphic_eq : Icons.music_note,
                    color: Colors.amber.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white)),
                      Text(
                        track.formatBadge,
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(engine.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white),
                  onPressed: () => engine.togglePlay(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
