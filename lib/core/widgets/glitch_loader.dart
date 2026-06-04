import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 机器故障风（Glitch / Cyberpunk）加载组件。
///
/// 视觉特征：
/// - "LOADING..." 文字带红青色彩偏差（Chromatic Aberration）抖动；
/// - 字母随机瞬间变成乱码字符（@ # * & _ x）再恢复，模拟系统损坏；
/// - CustomPainter 绘制微弱 CRT 扫描线 + 随机数字噪点；
/// - 进度条行进时带随机"信号卡顿/瞬间跳跃"。
///
/// 用法：
/// - 全屏：`GlitchLoader(fullScreen: true)`（铺满+半透明黑底，用于页面级加载）。
/// - 局部：`GlitchLoader(size: 120)`（嵌在卡片/列表占位）。
/// - 可选 `progress`（0..1）显示确定进度；不传则为不确定循环进度。
///
/// 全部基于 Flutter 原生 API（CustomPainter / AnimationController），无第三方依赖。
class GlitchLoader extends StatefulWidget {
  /// 是否全屏（铺满 + 半透明背景）。否则按 [size] 局部展示。
  final bool fullScreen;

  /// 局部展示时的区域边长（全屏时忽略）。
  final double size;

  /// 确定性进度 0..1；为 null 时显示不确定循环进度。
  final double? progress;

  /// 加载主文字。
  final String label;

  const GlitchLoader({
    super.key,
    this.fullScreen = false,
    this.size = 160,
    this.progress,
    this.label = 'LOADING...',
  });

  @override
  State<GlitchLoader> createState() => _GlitchLoaderState();
}

class _GlitchLoaderState extends State<GlitchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Random _rand = Random(0); // 固定种子起步，运行中靠时间推进产生变化

  @override
  void initState() {
    super.initState();
    // 1.4s 循环驱动所有故障效果（抖动/乱码/噪点/进度卡顿）。
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = SizedBox(
      width: widget.fullScreen ? null : widget.size,
      height: widget.fullScreen ? null : widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => _GlitchContent(
            t: _ctrl.value,
            rand: _rand,
            progress: widget.progress,
            label: widget.label,
            compact: !widget.fullScreen,
          ),
        ),
      ),
    );

    if (!widget.fullScreen) return Center(child: core);

    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.background.withValues(alpha: 0.82),
        child: Center(child: core),
      ),
    );
  }
}

/// 故障内容主体：文字（色彩偏差+乱码）+ 进度条 + 扫描线/噪点画层。
class _GlitchContent extends StatelessWidget {
  final double t; // 0..1 动画相位
  final Random rand;
  final double? progress;
  final String label;
  final bool compact;

  const _GlitchContent({
    required this.t,
    required this.rand,
    required this.progress,
    required this.label,
    required this.compact,
  });

  /// 乱码替换字符集。
  static const _glitchChars = ['@', '#', '*', '&', '_', 'x', '%', '/'];

  @override
  Widget build(BuildContext context) {
    // 用相位 t 离散出"帧种子"，让乱码/抖动按帧跳变而非连续平滑。
    final frame = (t * 28).floor();
    final fr = Random(frame * 9973 + 7);

    // 抖动偏移（高频小幅）。
    final jitterX = (fr.nextDouble() - 0.5) * 4;
    final jitterY = (fr.nextDouble() - 0.5) * 2;
    // 色彩偏差幅度（红/青分离），随机脉冲式放大。
    final pulse = fr.nextDouble() < 0.18 ? 4.0 : 1.6;

    final fontSize = compact ? 16.0 : 24.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 扫描线 + 噪点画层（铺满本组件区域）。
        Positioned.fill(
          child: CustomPaint(
            painter: _GlitchPainter(frame: frame, compact: compact),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(jitterX, jitterY),
              child: _chromaticText(_scramble(label, fr), fontSize, pulse),
            ),
            SizedBox(height: compact ? 12 : 20),
            _progressBar(fr),
          ],
        ),
      ],
    );
  }

  /// 随机把若干字母替换成乱码字符（瞬间损坏感）。
  String _scramble(String src, Random fr) {
    final chars = src.split('');
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == ' ' || chars[i] == '.') continue;
      // 每帧约 12% 概率某位损坏。
      if (fr.nextDouble() < 0.12) {
        chars[i] = _glitchChars[fr.nextInt(_glitchChars.length)];
      }
    }
    return chars.join();
  }

  /// 色彩偏差文字：底层红、青各偏移一点，顶层正常银白。
  Widget _chromaticText(String text, double fontSize, double offset) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 3,
      fontFeatures: const [],
    );
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(-offset, 0),
          child: Text(
            text,
            style: baseStyle.copyWith(
              color: AppColors.danger.withValues(alpha: 0.85),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(offset, 0),
          child: Text(
            text,
            style: baseStyle.copyWith(
              color: AppColors.coolAccent.withValues(alpha: 0.85),
            ),
          ),
        ),
        Text(text, style: baseStyle.copyWith(color: AppColors.silver)),
      ],
    );
  }

  /// 进度条：确定进度带随机"瞬间跳跃"扰动；不确定进度为来回扫动的光带。
  Widget _progressBar(Random fr) {
    final width = compact ? 100.0 : 220.0;
    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _ProgressPainter(
          t: t,
          progress: progress,
          jump: fr.nextDouble() < 0.22 ? (fr.nextDouble() - 0.5) * 0.12 : 0,
        ),
      ),
    );
  }
}

/// CRT 扫描线 + 随机数字噪点画层。
class _GlitchPainter extends CustomPainter {
  final int frame; // 帧序号，驱动噪点跳变
  final bool compact;

  _GlitchPainter({required this.frame, required this.compact});

  @override
  void paint(Canvas canvas, Size size) {
    // 1) CRT 扫描线：每隔 3px 一条极淡横线。
    final linePaint = Paint()
      ..color = AppColors.coolAccent.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2) 随机数字噪点：每帧固定种子 → 一批小亮点/暗点（不闪烁刺眼）。
    final fr = Random(frame * 6151 + 31);
    final count = compact ? 14 : 40;
    final noisePaint = Paint();
    for (var i = 0; i < count; i++) {
      final x = fr.nextDouble() * size.width;
      final y = fr.nextDouble() * size.height;
      final w = 1.0 + fr.nextDouble() * 2;
      final bright = fr.nextDouble() < 0.5;
      noisePaint.color = (bright ? AppColors.silver : AppColors.steel)
          .withValues(alpha: 0.06 + fr.nextDouble() * 0.12);
      canvas.drawRect(Rect.fromLTWH(x, y, w, 1), noisePaint);
    }

    // 3) 偶发横向撕裂带（信号错位感）。
    if (fr.nextDouble() < 0.25) {
      final ty = fr.nextDouble() * size.height;
      final th = 1.0 + fr.nextDouble() * 3;
      canvas.drawRect(
        Rect.fromLTWH(0, ty, size.width, th),
        Paint()..color = AppColors.danger.withValues(alpha: 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) => old.frame != frame;
}

/// 故障风进度条画层：确定进度带随机跳跃；不确定进度为来回扫动光带。
class _ProgressPainter extends CustomPainter {
  final double t; // 0..1 相位
  final double? progress; // 确定进度或 null
  final double jump; // 本帧的随机跳跃扰动

  _ProgressPainter({
    required this.t,
    required this.progress,
    required this.jump,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.coolAccent;
    if (progress != null) {
      // 确定进度 + 随机瞬间跳跃（夹在 0..1）。
      final p = (progress! + jump).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width * p, size.height), bg);
      // 头部亮一段，强调"信号头"。
      final headX = (size.width * p - 6).clamp(0.0, size.width);
      canvas.drawRect(
        Rect.fromLTWH(headX, 0, 6, size.height),
        Paint()..color = AppColors.silver.withValues(alpha: 0.9),
      );
    } else {
      // 不确定进度：一道光带来回扫动（用 t 三角波），带随机跳跃。
      final tri = t < 0.5 ? t * 2 : (1 - t) * 2; // 0→1→0
      final center = (tri + jump).clamp(0.0, 1.0);
      final bandW = size.width * 0.32;
      final left = (size.width * center - bandW / 2).clamp(
        0.0,
        size.width - bandW,
      );
      final rect = Rect.fromLTWH(left, 0, bandW, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.coolAccent.withValues(alpha: 0),
              AppColors.coolAccent,
              AppColors.coolAccent.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) =>
      old.t != t || old.progress != progress || old.jump != jump;
}
