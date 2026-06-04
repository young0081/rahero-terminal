import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 机器故障风（Glitch）路由 / 板块切换过渡。
///
/// 效果：进入页面像"信号重新连接"——前 ~70% 时间高频抖动 + RGB 通道分离重影
/// + 闪烁 + 水平撕裂条带，随后快速稳定为正常画面。路由过渡 380ms，板块切换 550ms。
/// 全部基于原生 API（AnimatedBuilder + Transform + ColorFiltered + CustomPaint），
/// 无第三方依赖。
///
/// 提供三种用法：
/// - [glitchTransitionPage]：go_router 的 CustomTransitionPage 工厂；
/// - [GlitchPageRoute]：Navigator.push 用的 PageRoute；
/// - [GlitchSwitcher]：板块切换（IndexedStack 式）用的包裹组件。
const Duration kGlitchDuration = Duration(milliseconds: 380);

/// 把动画值 [v]（0..1）映射成故障强度（前段强、后段速降到 0）。
double _glitchAmount(double v) {
  if (v >= 0.7) return 0; // 后 30% 完全稳定
  final p = 1 - (v / 0.7); // 0.7→0 映射为 0→1
  return p; // 线性衰减，前段保持较强故障感
}

/// 只保留红色通道并以红色输出的颜色矩阵（用于 RGB 分离重影）。
const ColorFilter _redChannel = ColorFilter.matrix(<double>[
  1, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// 只保留青色（绿+蓝）通道的颜色矩阵。
const ColorFilter _cyanChannel = ColorFilter.matrix(<double>[
  0, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// 故障过渡画面：对 [child] 施加抖动 + RGB 分离重影 + 闪烁 + 撕裂条带，
/// 强度由 amount 控制。
class GlitchTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  /// 反向（旧页淡出）：true 时随进度淡出。
  final bool outgoing;

  const GlitchTransition({
    super.key,
    required this.animation,
    required this.child,
    this.outgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        final amount = _glitchAmount(v);

        // 稳定阶段直接返回原内容，零开销。
        if (amount <= 0) return child;

        // 用动画值离散出帧种子，使抖动/撕裂按帧跳变。
        final frame = (v * 30).floor();
        final fr = Random(frame * 7919 + (outgoing ? 13 : 1));

        // 抖动幅度（明显）：随强度放大到 ±22 / ±10。
        final dx = (fr.nextDouble() - 0.5) * 22 * amount;
        final dy = (fr.nextDouble() - 0.5) * 10 * amount;
        // 闪烁：故障期偶发瞬间变暗。
        final flicker = fr.nextDouble() < 0.28
            ? 0.45 + fr.nextDouble() * 0.35
            : 1.0;
        final opacity = (outgoing ? (1 - v) : 1.0) * flicker;
        // RGB 分离偏移（明显）：随强度到 ±10px。
        final ghost = 10 * amount;

        // RGB 分离重影：红/青两层通道分离并左右错位，正常层降透明露出错位，
        // 在深色背景上也能显出红/青描边（modulate 在黑底不可见，故用通道矩阵分离）。
        final ghosted = Stack(
          children: [
            Transform.translate(
              offset: Offset(-ghost, 0),
              child: ColorFiltered(colorFilter: _redChannel, child: child),
            ),
            Transform.translate(
              offset: Offset(ghost, dy * 0.4),
              child: ColorFiltered(colorFilter: _cyanChannel, child: child),
            ),
            // 正常层降透明，让下面的红/青错位露出来。
            Opacity(opacity: 0.72, child: child),
          ],
        );

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: CustomPaint(
              foregroundPainter: _TearPainter(frame: frame, amount: amount),
              child: ghosted,
            ),
          ),
        );
      },
    );
  }
}

/// 故障撕裂条带覆盖层：随机几道水平条带，错位 + 半透明色块，强化"信号错乱"。
class _TearPainter extends CustomPainter {
  final int frame;
  final double amount;

  _TearPainter({required this.frame, required this.amount});

  @override
  void paint(Canvas canvas, Size size) {
    final fr = Random(frame * 104729 + 17);
    final bands = (3 + fr.nextInt(4)); // 3-6 道
    for (var i = 0; i < bands; i++) {
      final y = fr.nextDouble() * size.height;
      final h = (2 + fr.nextDouble() * 10) * amount;
      if (h < 0.5) continue;
      final color = fr.nextBool()
          ? const Color(0xFFE2473C) // 红
          : const Color(0xFF6078D8); // 蓝
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, h),
        Paint()..color = color.withValues(alpha: 0.18 * amount),
      );
    }
    // 偶发整屏极淡白闪。
    if (fr.nextDouble() < 0.2) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06 * amount),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TearPainter old) =>
      old.frame != frame || old.amount != amount;
}

/// go_router 用：把页面包成带故障过渡的 CustomTransitionPage。
CustomTransitionPage<T> glitchTransitionPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: kGlitchDuration,
    reverseTransitionDuration: kGlitchDuration,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      return GlitchTransition(animation: animation, child: child);
    },
  );
}

/// Navigator.push 用：故障风 PageRoute。
class GlitchPageRoute<T> extends PageRouteBuilder<T> {
  GlitchPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: kGlitchDuration,
        reverseTransitionDuration: kGlitchDuration,
        pageBuilder: (context, animation, secondary) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) =>
            GlitchTransition(animation: animation, child: child),
      );
}

/// 板块切换用：内容变化时以故障风切入新内容（类似 AnimatedSwitcher）。
///
/// 用 [childKey] 区分内容（如当前 tab 索引）；变化即触发一遍故障切入动画。
class GlitchSwitcher extends StatefulWidget {
  final Widget child;
  final Key childKey;

  const GlitchSwitcher({
    super.key,
    required this.child,
    required this.childKey,
  });

  @override
  State<GlitchSwitcher> createState() => _GlitchSwitcherState();
}

class _GlitchSwitcherState extends State<GlitchSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 板块切换用稍长时长（550ms），让故障段更可感知（路由过渡用 380ms）。
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..value = 1; // 初始已稳定（首帧不抖）
  }

  @override
  void didUpdateWidget(covariant GlitchSwitcher old) {
    super.didUpdateWidget(old);
    // 内容 key 变化 → 重播一遍故障切入。
    if (old.childKey != widget.childKey) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlitchTransition(
      animation: _ctrl,
      // KeyedSubtree 确保内容切换时整棵子树按新 key 重建。
      child: KeyedSubtree(key: widget.childKey, child: widget.child),
    );
  }
}
