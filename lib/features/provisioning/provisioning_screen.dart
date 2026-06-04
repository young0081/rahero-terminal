import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/effects/scanline_overlay.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glitch_loader.dart';
import 'asset_providers.dart';
import 'asset_service.dart';

/// 资源下载页：首次运行从库街区下载受版权素材并缓存，显示逐项进度。
///
/// 关键行为：
/// - 下载地址未配置或网络失败时不卡死，几秒后照常进入主界面（占位图兜底）。
/// - 已缓存的资源会被跳过（增量），二次启动几乎瞬间通过。
class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final Map<String, AssetProgress> _items = {};
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    // 监听同步流，累积每项最新状态。下载流自然结束或全部落定后进入主界面。
    ref.listen<AsyncValue<AssetProgress>>(assetSyncProvider, (prev, next) {
      next.whenData((p) {
        if (!mounted) return;
        setState(() => _items[p.id] = p);
      });
      next.whenOrNull(error: (err, stack) => _scheduleFinish());
      if (!_done && _allSettled()) {
        _finish();
      }
    });

    // 触发同步流订阅。
    ref.watch(assetSyncProvider);

    final total = _items.length;
    final ready = _items.values
        .where((e) => e.status == AssetStatus.ready)
        .length;
    final failed = _items.values
        .where((e) => e.status == AssetStatus.failed)
        .length;
    final skipped = _items.values
        .where((e) => e.status == AssetStatus.skipped)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScanlineOverlay(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.gapLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '接入资源服务',
                    style: TextStyle(
                      color: AppColors.silver,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXs),
                  Text(
                    skipped > 0 && skipped == total
                        ? '资源地址尚未上线，使用内置占位图（不影响体验）'
                        : '首次运行需下载势力图标等资源，之后将本地缓存离线可用',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppDimens.gapLg),
                  if (total > 0)
                    Center(
                      child: GlitchLoader(
                        size: 150,
                        progress: (ready + failed + skipped) / total,
                        label: 'SYNCING...',
                      ),
                    ),
                  const SizedBox(height: AppDimens.gapMd),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [for (final p in _items.values) _row(p)],
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('进入终端'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(AssetProgress p) {
    final (icon, color) = switch (p.status) {
      AssetStatus.ready => (Icons.check_circle, AppColors.coolAccent),
      AssetStatus.failed => (Icons.error_outline, AppColors.danger),
      AssetStatus.skipped => (Icons.remove_circle_outline, AppColors.textMuted),
      AssetStatus.downloading => (Icons.downloading, AppColors.steel),
      AssetStatus.pending => (Icons.schedule, AppColors.textMuted),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppDimens.gapSm),
          Expanded(
            child: Text(
              p.name,
              style: const TextStyle(color: AppColors.silver, fontSize: 14),
            ),
          ),
          if (p.status == AssetStatus.downloading)
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                value: p.fraction == 0 ? null : p.fraction,
              ),
            ),
        ],
      ),
    );
  }

  bool _allSettled() {
    if (_items.isEmpty) return false;
    return _items.values.every(
      (e) =>
          e.status == AssetStatus.ready ||
          e.status == AssetStatus.failed ||
          e.status == AssetStatus.skipped,
    );
  }

  void _scheduleFinish() {
    Future.delayed(const Duration(seconds: 2), _finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    context.go('/shell');
  }
}
