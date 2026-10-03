import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_format.dart';
import '../services/audio/player_engine.dart';
import '../ui/widgets/format_badge.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<PlayerEngine>();
    final track = engine.current;
    if (track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('正在播放')),
        body: const Center(child: Text('暂无播放')),
      );
    }
    final pos = engine.position;
    final dur = engine.duration;
    final ratio = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('正在播放')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 封面占位
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: track.codec.isDsd
                        ? [Colors.amber.withOpacity(0.4), Colors.deepOrange.withOpacity(0.3)]
                        : [Colors.deepPurple.withOpacity(0.4), Colors.blue.withOpacity(0.3)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    track.codec.isDsd ? Icons.graphic_eq : Icons.album,
                    size: 90,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(track.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (track.artist != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(track.artist!,
                    style: const TextStyle(color: Colors.white60)),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FormatBadge(codec: track.codec, text: track.formatBadge, fontSize: 13),
                if (engine.isDsd) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: engine.bitPerfect
                          ? Colors.green.withOpacity(0.18)
                          : Colors.grey.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: engine.bitPerfect
                              ? Colors.green
                              : Colors.grey),
                    ),
                    child: Text(
                      engine.bitPerfect ? '比特完美' : '非比特完美',
                      style: TextStyle(
                        color: engine.bitPerfect ? Colors.green : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (engine.dsdMode != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(engine.dsdMode!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            const Spacer(),
            // 进度
            Slider(
              value: ratio,
              onChanged: (v) =>
                  engine.seek(Duration(milliseconds: (v * dur.inMilliseconds).round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos), style: const TextStyle(color: Colors.white54)),
                  Text(_fmt(dur), style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 控制
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: engine.hasPrev ? engine.prev : null,
                ),
                IconButton(
                  icon: Icon(
                    engine.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 64,
                    color: Colors.amber,
                  ),
                  onPressed: engine.togglePlay,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: engine.hasNext ? engine.next : null,
                ),
              ],
            ),
            if (engine.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(engine.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            const Text(
              'DSD 比特完美直出需在 Android / 鸿蒙真机 + 支持 DoP / Native DSD 的 USB DAC 下生效。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
