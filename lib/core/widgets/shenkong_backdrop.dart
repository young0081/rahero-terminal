import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asset_manifest.dart';
import '../../features/provisioning/asset_providers.dart';
import '../theme/app_theme.dart';

/// 主界面背景：深空联合 LOGO 水印。
///
/// 深空联合是终端的归属方，主界面背景印有其 LOGO（很淡的水印）。
/// 版权方案：
/// - 优先加载「下载来的」深空联合 LOGO 图（logo_shenkong），以极低透明度做水印；
/// - 素材未下载时，降级为代码绘制的抽象冷色 motif（星芒 + 同心轨道环，
///   不复制原 LOGO 字形），保证观感且不触碰版权。
///
/// 该组件铺满父容器并位于内容之下，用 [IgnorePointer] 不拦截交互。
class ShenkongBackdrop extends ConsumerStatefulWidget {
  const ShenkongBackdrop({super.key});

  @override
  ConsumerState<ShenkongBackdrop> createState() => _ShenkongBackdropState();
}

class _ShenkongBackdropState extends ConsumerState<ShenkongBackdrop> {
  String? _logoPath;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final service = ref.read(assetServiceProvider);
      final manifest = await service.loadManifest();
      final AssetEntry? entry = manifest.byId('logo_shenkong');
      if (entry != null && await service.isReady(entry)) {
        final path = await service.localPath(entry);
        if (await File(path).exists()) {
          if (!mounted) return;
          setState(() {
            _logoPath = path;
            _resolved = true;
          });
          return;
        }
      }
    } catch (_) {
      // 忽略，走降级
    }
    if (!mounted) return;
    setState(() => _resolved = true);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.62,
          heightFactor: 0.62,
          child: _logoPath != null
              ? Opacity(
                  opacity: 0.06,
                  child: Image.file(
                    File(_logoPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const _MotifBackdrop(),
                  ),
                )
              : (_resolved
                  ? const _MotifBackdrop()
                  : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// 抽象冷色 motif 占位水印（不复制任何真实 LOGO 字形）。
class _MotifBackdrop extends StatelessWidget {
  const _MotifBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MotifPainter(),
    );
  }
}

class _MotifPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = math.min(size.width, size.height) / 2;

    // 同心轨道环（很淡）
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.steel.withValues(alpha: 0.07);
    for (final f in [0.45, 0.7, 0.95]) {
      canvas.drawCircle(center, baseR * f, ringPaint);
    }

    // 一条倾斜轨道椭圆
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: baseR * 1.9, height: baseR * 0.8),
      ringPaint,
    );
    canvas.restore();

    // 中心四角星芒（呼应深空联合 LOGO 的星芒元素，抽象化）
    _drawSparkle(canvas, center, baseR * 0.5,
        AppColors.coolAccent.withValues(alpha: 0.10));
    // 右上小星芒
    _drawSparkle(canvas, center + Offset(baseR * 0.6, -baseR * 0.6),
        baseR * 0.16, AppColors.silver.withValues(alpha: 0.08));
    // 左下小星芒
    _drawSparkle(canvas, center + Offset(-baseR * 0.65, baseR * 0.55),
        baseR * 0.12, AppColors.silver.withValues(alpha: 0.06));
  }

  /// 画一个四角星芒（菱形拉伸的尖角星）。
  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    const waist = 0.16; // 腰部收窄比例
    path.moveTo(c.dx, c.dy - r); // 上
    path.lineTo(c.dx + r * waist, c.dy - r * waist);
    path.lineTo(c.dx + r, c.dy); // 右
    path.lineTo(c.dx + r * waist, c.dy + r * waist);
    path.lineTo(c.dx, c.dy + r); // 下
    path.lineTo(c.dx - r * waist, c.dy + r * waist);
    path.lineTo(c.dx - r, c.dy); // 左
    path.lineTo(c.dx - r * waist, c.dy - r * waist);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MotifPainter oldDelegate) => false;
}
