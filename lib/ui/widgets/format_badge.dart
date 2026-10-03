import 'package:flutter/material.dart';
import '../../models/audio_format.dart';

/// 格式徽章：DSD 金色、无损蓝色、有损灰色
class FormatBadge extends StatelessWidget {
  final AudioCodec codec;
  final String text;
  final double fontSize;
  const FormatBadge(
      {Key? key, required this.codec, required this.text, this.fontSize = 11})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = codec.isDsd
        ? Colors.amber.shade300
        : codec.isLossless
            ? Colors.lightBlue.shade300
            : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
    );
  }
}
