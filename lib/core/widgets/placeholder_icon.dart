import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 资源缺失/未下载时的占位图，用代码绘制（不打包二进制图）。
///
/// 画一个带辉光的六边形 + 势力名首字。辉光颜色按势力专属色：
/// 星炬学院=绿、深空联合=红、其余=终端冷调银蓝。
class PlaceholderIcon extends StatelessWidget {
  final String label;
  final double size;

  /// 强调色（描边/辉光）。不传则用终端冷调强调色。
  final Color accent;

  const PlaceholderIcon({
    super.key,
    required this.label,
    this.size = 96,
    this.accent = AppColors.coolAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PlaceholderPainter(
          label: label.isEmpty ? '?' : label.characters.first,
          accent: accent,
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  final String label;
  final Color accent;

  _PlaceholderPainter({required this.label, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * 0.82;

    // 背景圆角面板
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppDimens.radiusMedium),
    );
    canvas.drawRRect(bgRect, Paint()..color = AppColors.surfaceHigh);

    // 辉光六边形描边
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 6;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        hexPath.moveTo(p.dx, p.dy);
      } else {
        hexPath.lineTo(p.dx, p.dy);
      }
    }
    hexPath.close();

    // 辉光底层
    canvas.drawPath(
      hexPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = accent.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 实线描边
    canvas.drawPath(
      hexPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = accent,
    );

    // 首字
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.silver,
          fontSize: r * 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PlaceholderPainter old) =>
      old.label != label || old.accent != accent;
}
