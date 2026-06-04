import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

/// 桌面无边框窗口的自绘标题条（银灰冷色调）。
///
/// - 左侧：终端标识小图标 + 应用名；
/// - 中部：可拖动区域（拖动移动窗口，双击最大化/还原）；
/// - 右侧：最小化 / 最大化(还原) / 关闭 按钮。
///
/// 仅在桌面平台使用；移动端不应挂载本组件。
class TitleBar extends StatefulWidget {
  /// 标题条高度。
  final double height;

  const TitleBar({super.key, this.height = 40});

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppDimens.gapMd),
          // 终端标识小图标（抽象四角星芒）
          const _Sigil(size: 16),
          const SizedBox(width: AppDimens.gapSm),
          const Text(
            '拉海洛终端  RAHERO TERMINAL',
            style: TextStyle(
              color: AppColors.silver,
              fontSize: 12.5,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 中部可拖动区域
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: const SizedBox.expand(),
            ),
          ),
          // 窗口控制按钮
          _WinButton(
            icon: Icons.remove,
            tooltip: '最小化',
            onPressed: () => windowManager.minimize(),
          ),
          _WinButton(
            icon: _maximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _maximized ? 13 : 15,
            tooltip: _maximized ? '还原' : '最大化',
            onPressed: _toggleMaximize,
          ),
          _WinButton(
            icon: Icons.close,
            tooltip: '关闭',
            hoverColor: AppColors.danger,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

/// 抽象四角星芒小图标（呼应深空联合星芒元素，不复制真实 LOGO）。
class _Sigil extends StatelessWidget {
  final double size;
  const _Sigil({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SigilPainter()),
    );
  }
}

class _SigilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    const waist = 0.18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * waist, c.dy - r * waist)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * waist, c.dy + r * waist)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * waist, c.dy + r * waist)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * waist, c.dy - r * waist)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.coolAccent);
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) => false;
}

/// 窗口控制按钮（带悬停高亮）。
class _WinButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final double iconSize;

  const _WinButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColor,
    this.iconSize = 16,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover
        ? (widget.hoverColor ?? AppColors.surfaceHigh)
        : Colors.transparent;
    final fg = (_hover && widget.hoverColor != null)
        ? Colors.white
        : AppColors.steel;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: 40,
            color: bg,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}
