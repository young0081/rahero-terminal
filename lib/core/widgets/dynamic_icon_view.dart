import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/asset_manifest.dart';
import '../../features/provisioning/asset_providers.dart';
import '../theme/app_theme.dart';
import 'placeholder_icon.dart';

/// 统一动态图标组件。
///
/// 根据清单里资源的 type 分发渲染方式：
/// - video（MP4）：用 video_player 循环静音播放；
/// - gif / image：用 Image.file 从本地缓存加载；
/// - 资源未就绪 / 加载失败：降级为 [PlaceholderIcon]（绝不崩溃、不空白）。
///
/// 资源一律从「本地缓存」读取（Image.file / File），不是 Image.asset，
/// 因为受版权素材是运行时下载来的，不打包进 app。
class DynamicIconView extends ConsumerStatefulWidget {
  /// 资源 id（对应 asset_manifest.json 的 assets[].id）。
  final String assetId;

  /// 显示尺寸。
  final double size;

  /// 占位时显示的文字（一般传势力名）。
  final String label;

  /// 是否自动播放视频（默认 true，循环静音）。
  final bool autoPlay;

  /// 优先静态末帧：列表缩略图场景设为 true，只显示静态 LOGO 末帧，
  /// 不加载循环视频，省内存、不抢眼。
  final bool preferStill;

  const DynamicIconView({
    super.key,
    required this.assetId,
    required this.label,
    this.size = 96,
    this.autoPlay = true,
    this.preferStill = false,
  });

  @override
  ConsumerState<DynamicIconView> createState() => _DynamicIconViewState();
}

class _DynamicIconViewState extends ConsumerState<DynamicIconView> {
  VideoPlayerController? _video;
  String? _resolvedPath;
  String? _seedAssetKey; // 本地种子图 asset key（缓存未就绪时的兜底）
  AssetEntry? _entry;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant DynamicIconView old) {
    super.didUpdateWidget(old);
    if (old.assetId != widget.assetId) {
      _disposeVideo();
      setState(() {
        _loading = true;
        _failed = false;
        _resolvedPath = null;
        _seedAssetKey = null;
      });
      _resolve();
    }
  }

  Future<void> _resolve() async {
    try {
      final service = ref.read(assetServiceProvider);
      final manifest = await service.loadManifest();
      final entry = manifest.byId(widget.assetId);
      if (entry == null) {
        await _trySeedThenFail();
        return;
      }
      _entry = entry;
      final ready = await service.isReady(entry);
      if (!ready) {
        await _trySeedThenFail();
        return;
      }
      final path = await service.localPath(entry);
      if (!await File(path).exists()) {
        await _trySeedThenFail();
        return;
      }
      // 缩略图模式遇到视频资源：不能用 Image.file 加载 MP4，
      // 改走种子末帧 PNG（或占位图），避免解码失败后白白降级。
      if (entry.type == 'video' && widget.preferStill) {
        await _trySeedThenFail();
        return;
      }
      if (entry.type == 'video') {
        await _initVideo(path);
      }
      if (!mounted) return;
      setState(() {
        _resolvedPath = path;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      await _trySeedThenFail();
    }
  }

  /// 缓存未就绪时，尝试加载打进 app 的本地种子图（`assets/local_seed/<id>.png`）；
  /// 命中则用它，否则降级为占位图。
  Future<void> _trySeedThenFail() async {
    final key = 'assets/local_seed/${widget.assetId}.png';
    try {
      await rootBundle.load(key);
      if (!mounted) return;
      setState(() {
        _seedAssetKey = key;
        _loading = false;
        _failed = false;
      });
      return;
    } catch (_) {
      // 无种子图，走占位
    }
    _markFailed();
  }

  Future<void> _initVideo(String path) async {
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0);
    if (widget.autoPlay) {
      await controller.play();
    }
    _video = controller;
  }

  void _markFailed() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = true;
    });
  }

  void _disposeVideo() {
    _video?.dispose();
    _video = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 本地种子图（缓存未就绪时的兜底，打进 app 的 assets/local_seed）
    if (_seedAssetKey != null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset(
          _seedAssetKey!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => PlaceholderIcon(
            label: widget.label,
            size: widget.size,
            accent: AppColors.factionAccent(widget.assetId),
          ),
        ),
      );
    }

    if (_failed || _resolvedPath == null || _entry == null) {
      return PlaceholderIcon(
        label: widget.label,
        size: widget.size,
        accent: AppColors.factionAccent(widget.assetId),
      );
    }

    final entry = _entry!;
    if (entry.type == 'video' && _video != null && _video!.value.isInitialized) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _video!.value.size.width,
            height: _video!.value.size.height,
            child: VideoPlayer(_video!),
          ),
        ),
      );
    }

    // gif / image 走 Image.file
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.file(
        File(_resolvedPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => PlaceholderIcon(
          label: widget.label,
          size: widget.size,
          accent: AppColors.factionAccent(widget.assetId),
        ),
      ),
    );
  }
}
