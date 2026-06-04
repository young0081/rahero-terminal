import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 聊天背景：暗六角网格水印 + 渐变暗角 + 可选粒子漂浮（静态版）。
class ChatBackground extends StatelessWidget {
  final Widget child;
  final bool showParticles;

  const ChatBackground({
    super.key,
    required this.child,
    this.showParticles = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 基础背景色
        Container(color: AppColors.background),

        // 六角网格水印
        const Positioned.fill(child: _HexGridPattern()),

        // 渐变暗角（静态）
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  AppColors.coolAccent.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.5, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // 粒子层（可选）
        if (showParticles) const Positioned.fill(child: _FloatingParticles()),

        // 内容层
        child,
      ],
    );
  }
}

/// 六角网格图案（CustomPainter 代码绘制）
class _HexGridPattern extends StatelessWidget {
  const _HexGridPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HexGridPainter(),
      child: Container(),
    );
  }
}

class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.coolAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const hexRadius = 30.0;
    const hexHeight = hexRadius * 1.732; // sqrt(3)
    const hexWidth = hexRadius * 1.5;

    for (double y = -hexHeight; y < size.height + hexHeight; y += hexHeight) {
      for (double x = -hexRadius * 2;
          x < size.width + hexRadius * 2;
          x += hexWidth * 2) {
        _drawHex(canvas, paint, Offset(x, y), hexRadius);
        _drawHex(
            canvas, paint, Offset(x + hexWidth, y + hexHeight / 2), hexRadius);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * 3.14159 / 180;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 漂浮粒子动画（数据流效果）
class _FloatingParticles extends StatefulWidget {
  const _FloatingParticles();

  @override
  State<_FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<_FloatingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 生成20个随机粒子
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle.random());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlesPainter(_particles, _controller.value),
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double speed;
  final double size;

  _Particle(this.x, this.y, this.speed, this.size);

  factory _Particle.random() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return _Particle(
      (random % 1000) / 1000,
      (random % 500) / 500,
      0.3 + (random % 100) / 500,
      2 + (random % 30) / 10,
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlesPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.coolAccent.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      final y = ((p.y + progress * p.speed) % 1.0) * size.height;
      final x = p.x * size.width;
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
