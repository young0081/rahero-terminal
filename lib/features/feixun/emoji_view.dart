import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provisioning/asset_providers.dart';

/// 表情视图：优先显示从库街区下载的表情贴图，未下载时用 unicode 字形兜底。
///
/// 解析顺序：下载缓存(emojiId) → 打进 app 的本地种子(`assets/local_seed/<id>.png`)
/// → unicode 字形(glyph，Windows 渲染为彩色 Segoe Emoji)。
class EmojiView extends ConsumerStatefulWidget {
  final String emojiId;
  final String glyph;
  final double size;

  const EmojiView({
    super.key,
    required this.emojiId,
    required this.glyph,
    this.size = 28,
  });

  @override
  ConsumerState<EmojiView> createState() => _EmojiViewState();
}

class _EmojiViewState extends ConsumerState<EmojiView> {
  String? _filePath;
  String? _assetKey;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant EmojiView old) {
    super.didUpdateWidget(old);
    if (old.emojiId != widget.emojiId) {
      _filePath = null;
      _assetKey = null;
      _resolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final service = ref.read(assetServiceProvider);
    try {
      final manifest = await service.loadManifest();
      final entry = manifest.byId(widget.emojiId);
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
    final key = 'assets/local_seed/${widget.emojiId}.png';
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
    if (_resolved && _filePath != null) {
      return Image.file(File(_filePath!),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _glyph());
    }
    if (_resolved && _assetKey != null) {
      return Image.asset(_assetKey!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _glyph());
    }
    // 未就绪 / 无贴图 → unicode 字形
    return _glyph();
  }

  Widget _glyph() => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          // FittedBox 确保字形整体等比缩放进盒内，不被行高 / 基线裁剪。
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              widget.glyph,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ),
      );
}
