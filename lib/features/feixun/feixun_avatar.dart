import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dynamic_icon_view.dart';
import '../provisioning/asset_providers.dart';

/// 用户自定义头像路径的响应式状态。
///
/// 持久化在 AppStorage，上传/重置后所有显示「我」的头像处即时刷新。
class UserAvatarNotifier extends Notifier<String?> {
  @override
  String? build() => AppStorage.getUserAvatarPath();

  /// 设置自定义头像（绝对路径，已复制到 app 目录）。
  Future<void> setAvatar(String path) async {
    await AppStorage.setUserAvatarPath(path);
    state = path;
  }

  /// 重置为默认（漂泊者 / 星芒占位）。
  Future<void> reset() async {
    final old = AppStorage.getUserAvatarPath();
    await AppStorage.setUserAvatarPath(null);
    state = null;
    // 顺手清理旧的自定义头像文件
    if (old != null) {
      try {
        final f = File(old);
        if (await f.exists()) await f.delete();
      } catch (_) {/* ignore */}
    }
  }
}

final userAvatarProvider =
    NotifierProvider<UserAvatarNotifier, String?>(UserAvatarNotifier.new);

/// 飞讯头像（势力联系人）：圆角方形底 + 势力 LOGO（静态末帧，去黑底透明图）。
class FeixunAvatar extends StatelessWidget {
  final String assetId;
  final String label;
  final double size;

  const FeixunAvatar({
    super.key,
    required this.assetId,
    required this.label,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.factionAccent(assetId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          // 外发光环
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          // 悬浮阴影
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: DynamicIconView(
          assetId: assetId,
          label: label,
          size: size * 0.76,
          preferStill: true,
        ),
      ),
    );
  }
}

/// 「我」（终端用户）的头像。
///
/// 优先级：自定义上传头像 → 漂泊者头像（avatar_rover，运行时从库街区下载）
/// → 终端星芒占位（代码绘制）。
class SelfAvatar extends ConsumerWidget {
  final double size;
  const SelfAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPath = ref.watch(userAvatarProvider);

    final border = Border.all(
        color: AppColors.coolAccent.withValues(alpha: 0.5), width: 1.5);
    final radius = BorderRadius.circular(AppDimens.radiusMedium);
    final shadow = [
      // 青色外发光
      BoxShadow(
        color: AppColors.coolAccent.withValues(alpha: 0.3),
        blurRadius: 10,
        spreadRadius: 1,
      ),
      // 悬浮阴影
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];

    // 1) 自定义上传头像
    if (customPath != null && customPath.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: radius,
          border: border,
          boxShadow: shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(customPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // 文件丢失则降级到漂泊者/星芒
          errorBuilder: (context, error, stack) => _RoverOrSigil(size: size),
        ),
      );
    }

    // 2) 漂泊者 / 星芒占位
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: radius,
        border: border,
        boxShadow: shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: _RoverOrSigil(size: size),
    );
  }
}

/// 漂泊者头像（运行时从库街区下载）→ 未就绪则星芒占位。
///
/// 解析顺序：下载缓存(avatar_rover) → 打进 app 的本地种子
/// (assets/local_seed/avatar_rover.png) → 星芒占位（代码绘制）。
class _RoverOrSigil extends ConsumerStatefulWidget {
  final double size;
  const _RoverOrSigil({required this.size});

  @override
  ConsumerState<_RoverOrSigil> createState() => _RoverOrSigilState();
}

class _RoverOrSigilState extends ConsumerState<_RoverOrSigil> {
  String? _filePath; // 下载缓存文件
  String? _assetKey; // 本地种子
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final service = ref.read(assetServiceProvider);
    try {
      final manifest = await service.loadManifest();
      final entry = manifest.byId('avatar_rover');
      if (entry != null && await service.isReady(entry)) {
        final p = await service.localPath(entry);
        if (await File(p).exists()) {
          if (!mounted) return;
          setState(() {
            _filePath = p;
            _resolved = true;
          });
          return;
        }
      }
    } catch (_) {/* ignore */}
    // 本地种子兜底
    const key = 'assets/local_seed/avatar_rover.png';
    try {
      await rootBundle.load(key);
      if (!mounted) return;
      setState(() {
        _assetKey = key;
        _resolved = true;
      });
      return;
    } catch (_) {/* 无种子 */}
    if (!mounted) return;
    setState(() => _resolved = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      return _SigilPlaceholder(size: widget.size);
    }
    if (_filePath != null) {
      return Image.file(File(_filePath!),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              _SigilPlaceholder(size: widget.size));
    }
    if (_assetKey != null) {
      return Image.asset(_assetKey!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              _SigilPlaceholder(size: widget.size));
    }
    return _SigilPlaceholder(size: widget.size);
  }
}

/// 终端星芒占位（代码绘制，冷调）。
class _SigilPlaceholder extends StatelessWidget {
  final double size;
  const _SigilPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SelfSigilPainter(),
    );
  }
}

class _SelfSigilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.3;
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
  bool shouldRepaint(covariant _SelfSigilPainter oldDelegate) => false;
}
