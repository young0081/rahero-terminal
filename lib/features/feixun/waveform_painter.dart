import 'package:flutter/material.dart';

/// 语音消息波形占位绘制器。
class WaveformPainter extends CustomPainter {
  final Color color;

  WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // 绘制 12 个随机高度的竖线模拟波形
    const barCount = 12;
    final barWidth = size.width / barCount;
    final heights = [0.3, 0.6, 0.9, 0.7, 0.4, 0.8, 1.0, 0.5, 0.6, 0.9, 0.4, 0.7];

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final barHeight = size.height * heights[i];
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
