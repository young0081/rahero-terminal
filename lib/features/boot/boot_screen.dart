import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/effects/scanline_overlay.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logo_animation_view.dart';

/// 开机页：播放深空联合（带文字）LOGO 动画 + 终端自检文字序列，
/// 动画播完后进入资源下载页。
///
/// 深空联合是终端的归属方，开机动画用带文字的完整版 LOGO。
/// 即使素材未就绪，LogoAnimationView 也会降级为占位并照常触发收尾，
/// 配合保底超时，绝不卡在开机页。所有定时器在 dispose 时取消。
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  final List<String> _lines = const [
    '> 拉海洛终端 RAHERO TERMINAL',
    '[ OK ] 终端内核加载完成',
    '[ OK ] 飞讯通讯模块就绪',
    '[ OK ] 势力档案索引就绪',
    '[ .. ] 正在接入资源服务...',
  ];

  int _shown = 0;
  bool _navigated = false;

  Timer? _textTimer;
  Timer? _fallbackTimer;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    // 逐行显示自检文字（每 420ms 一行）。
    _textTimer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_shown >= _lines.length) {
        t.cancel();
        return;
      }
      setState(() => _shown++);
    });
    // 卡死看门狗：动画每推进一帧都会重置它（见 onProgress）。只有在 8 秒内
    // 既无新帧、又未收到播完回调（真正卡死/解码失败）时才兜底进入下一步。
    // 这样比兜底超时更长的动画（开机 LOGO 约 10 秒）也能完整播放，不被切断。
    _resetWatchdog();
  }

  /// 重置卡死看门狗：取消旧定时器并重新计 8 秒。
  void _resetWatchdog() {
    if (_navigated) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 8), _goNext);
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _fallbackTimer?.cancel();
    _navTimer?.cancel();
    super.dispose();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/provisioning');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final logo = LogoAnimationView(
      assetId: 'boot_shenkong',
      label: '深空联合',
      size: isWide ? 280 : 200,
      // 每帧推进都重置看门狗，确保 10 秒长动画不被 8 秒兜底切断。
      onProgress: _resetWatchdog,
      // 动画播完 → 略停顿展示完整 LOGO → 进入下一步
      onFinished: () {
        _fallbackTimer?.cancel();
        _navTimer?.cancel();
        _navTimer = Timer(const Duration(milliseconds: 900), _goNext);
      },
    );

    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < _shown; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              _lines[i],
              style: TextStyle(
                color: _lines[i].startsWith('[ OK ]')
                    ? AppColors.coolAccent
                    : AppColors.silver,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScanlineOverlay(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.gapLg),
            child: isWide
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(width: AppDimens.gapXl),
                      texts,
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(height: AppDimens.gapLg),
                      texts,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
