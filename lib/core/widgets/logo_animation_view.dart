import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/provisioning/asset_providers.dart';
import '../theme/app_theme.dart';
import 'placeholder_icon.dart';

/// LOGO 动画视图：点开势力详情时，播放一遍透明 LOGO 动画（APNG），
/// 播完后定格在最后一帧（完整 LOGO）。
///
/// 实现要点：
/// - 动画为带透明通道的 APNG（黑底已抠除），用 Flutter 原生 `ui.Codec` 逐帧驱动，
///   因此透明部分能与深色界面自然融合，不会出现突兀黑块。
/// - 「播一遍停最后一帧」：手动按帧推进，到最后一帧后停止，定格不循环。
/// - 资源解析顺序：下载缓存(`<id>.apng`/末帧) → 打进 app 的本地种子
///   (`assets/local_seed/<id>.apng`、`<id>.png`) → 占位图。
/// - 无动画但有末帧静图：直接显示末帧；都没有则占位。
class LogoAnimationView extends ConsumerStatefulWidget {
  /// 实体基础 id（如 faction_xingju）。
  final String assetId;
  final String label;
  final double size;

  /// 动画播放完成（或无动画直接定格末帧）时回调一次。开机页可据此进入下一步。
  final VoidCallback? onFinished;

  /// 每推进一帧回调一次。开机页据此重置"卡死看门狗"，
  /// 避免比兜底超时更长的动画（如 10s 开机 LOGO）被提前切断。
  final VoidCallback? onProgress;

  const LogoAnimationView({
    super.key,
    required this.assetId,
    required this.label,
    this.size = 180,
    this.onFinished,
    this.onProgress,
  });

  @override
  ConsumerState<LogoAnimationView> createState() => _LogoAnimationViewState();
}

class _LogoAnimationViewState extends ConsumerState<LogoAnimationView>
    with SingleTickerProviderStateMixin {
  ui.Codec? _codec;
  ui.Image? _currentImage;
  bool _resolving = true;
  bool _hasAnim = false;
  int _frameIndex = 0;
  int _frameCount = 0;
  Timer? _frameTimer;

  // 末帧静图兜底
  String? _stillFilePath;
  String? _stillAssetKey;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _currentImage?.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    // 1) 末帧静图（缓存优先，其次种子）
    final service = ref.read(assetServiceProvider);
    try {
      final manifest = await service.loadManifest();
      final stillEntry = manifest.byId(widget.assetId);
      if (stillEntry != null && await service.isReady(stillEntry)) {
        final p = await service.localPath(stillEntry);
        if (await File(p).exists()) _stillFilePath = p;
      }
    } catch (_) {/* ignore */}
    if (_stillFilePath == null) {
      final key = 'assets/local_seed/${widget.assetId}.png';
      if (await _assetExists(key)) _stillAssetKey = key;
    }

    // 2) 动画 APNG 字节（缓存优先，其次种子）
    Uint8List? animBytes;
    try {
      final manifest = await service.loadManifest();
      final animEntry = manifest.byId('${widget.assetId}_anim');
      if (animEntry != null && await service.isReady(animEntry)) {
        final p = await service.localPath(animEntry);
        final f = File(p);
        if (await f.exists()) animBytes = await f.readAsBytes();
      }
    } catch (_) {/* ignore */}
    if (animBytes == null) {
      final key = 'assets/local_seed/${widget.assetId}.apng';
      if (await _assetExists(key)) {
        final data = await rootBundle.load(key);
        animBytes = data.buffer.asUint8List();
      }
    }

    if (animBytes == null) {
      // 无动画：定格末帧（或占位）
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _hasAnim = false;
      });
      _notifyFinished();
      return;
    }

    // 3) 解码 APNG 并逐帧播放一遍
    try {
      final codec = await ui.instantiateImageCodec(animBytes);
      _codec = codec;
      _frameCount = codec.frameCount;
      if (!mounted) {
        codec.dispose();
        return;
      }
      setState(() {
        _resolving = false;
        _hasAnim = true;
      });
      _playNextFrame();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _hasAnim = false;
      });
      _notifyFinished();
    }
  }

  bool _finishedNotified = false;

  /// 收尾回调（仅触发一次）。
  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    widget.onFinished?.call();
  }

  Future<void> _playNextFrame() async {
    final codec = _codec;
    if (codec == null || !mounted) return;

    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    _currentImage?.dispose();
    setState(() {
      _currentImage = frame.image;
    });
    widget.onProgress?.call(); // 通知外部：动画在推进（重置卡死看门狗）

    _frameIndex++;
    // 播到最后一帧即停（定格），不循环。
    if (_frameIndex >= _frameCount) {
      _notifyFinished();
      return;
    }
    final delay = frame.duration == Duration.zero
        ? const Duration(milliseconds: 50)
        : frame.duration;
    _frameTimer = Timer(delay, _playNextFrame);
  }

  Future<bool> _assetExists(String key) async {
    try {
      await rootBundle.load(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _placeholder() => PlaceholderIcon(
        label: widget.label,
        size: widget.size,
        accent: AppColors.factionAccent(widget.assetId),
      );

  Widget _still() {
    if (_stillFilePath != null) {
      return Image.file(File(_stillFilePath!),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _placeholder());
    }
    if (_stillAssetKey != null) {
      return Image.asset(_stillAssetKey!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _placeholder());
    }
    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_resolving) {
      content = const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_hasAnim && _currentImage != null) {
      content = RawImage(
        image: _currentImage,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    } else {
      content = _still();
    }

    return SizedBox(width: widget.size, height: widget.size, child: content);
  }
}
