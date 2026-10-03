import 'package:flutter/material.dart';
import '../../models/audio_format.dart';
import '../../models/track.dart';
import 'format_badge.dart';

/// 曲目列表项
class TrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final VoidCallback? onTap;

  const TrackTile(
      {Key? key, required this.track, this.isCurrent = false, this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.amber.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          track.codec.isDsd ? Icons.graphic_eq : Icons.music_note,
          color: isCurrent ? Colors.amber : Colors.white70,
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? Colors.amber.shade200 : Colors.white,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: track.artist != null
          ? Text(track.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12))
          : null,
      trailing: FormatBadge(codec: track.codec, text: track.formatBadge),
      onTap: onTap,
    );
  }
}
