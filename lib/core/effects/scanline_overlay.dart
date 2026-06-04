import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 终端扫描线 / 噪点 / 暗角叠加层。
///
/// 用 [IgnorePointer] 包裹，绝不拦截用户交互。性能友好：
/// 扫描线为静态重复绘制；可通过 [animate] 让扫描线缓慢移动。
class ScanlineOverlay extends StatefulWidget {
  final Widget child;

  /// 是否启用动画（低端设备可关闭）。
  final bool animate;

  /// 扫描线强度 0..1。
  final double intensity;

  const ScanlineOverlay({
    super.key,
    required this.child,
    this.animate = true,
    this.intensity = 0.5,
  });

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animate) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ScanlineOverlay old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanlinePainter(
                  phase: _ctrl.value,
                  intensity: widget.intensity.clamp(0, 1),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double phase;
  final double intensity;

  _ScanlinePainter({required this.phase, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    // 扫描线：每 3px 一条暗线
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10 * intensity);
    const gap = 3.0;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), linePaint);
    }

    // 移动的高光扫描带
    final bandY = phase * size.height;
    final bandRect = Rect.fromLTWH(0, bandY - 40, size.width, 80);
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.coolGlow.withValues(alpha: 0.06 * intensity),
          Colors.transparent,
        ],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);

    // 暗角
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35 * intensity),
        ],
        stops: const [0.7, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) =>
      old.phase != phase || old.intensity != intensity;
}

/// 一个带辉光描边的终端面板容器，统一卡片观感。
class TerminalPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color glow;

  const TerminalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.gapMd),
    this.glow = AppColors.coolGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 12, spreadRadius: -4),
        ],
      ),
      child: child,
    );
  }
}
