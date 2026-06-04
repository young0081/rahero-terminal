import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import 'feixun_avatar.dart';

/// 用户头像上传/重置的共享逻辑。设置页与「点头像」入口共用。
class AvatarPicker {
  AvatarPicker._();

  /// 让用户选择一张图片作为自定义头像，复制到 app 目录并持久化。
  /// 返回提示文案（成功/取消/失败），由调用方决定如何展示。
  static Future<String> pickAndSet(WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (picked == null) {
        return '已取消';
      }

      final src = File(picked.path);
      if (!await src.exists()) {
        return '无法读取所选文件';
      }

      // 复制到 app 文档目录，避免引用的原文件被移动/删除后头像丢失。
      final docDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${docDir.path}/rahero_terminal/avatar');
      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }
      final ext = _ext(picked);
      // 用时间戳命名，换头像时旧文件由 reset 清理；这里覆盖式写入固定名也可，
      // 但带时间戳能避免图片缓存不刷新的问题。
      final destPath =
          '${avatarDir.path}/user_avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
      await src.copy(destPath);

      // 先重置（清理旧文件），再设新路径。
      await ref.read(userAvatarProvider.notifier).reset();
      await ref.read(userAvatarProvider.notifier).setAvatar(destPath);
      return '头像已更新';
    } catch (e) {
      return '设置头像失败：$e';
    }
  }

  static String _ext(XFile file) {
    final candidates = <String?>[file.name, file.path, file.mimeType];
    for (final value in candidates) {
      if (value == null || value.isEmpty) continue;
      final lower = value.toLowerCase();
      if (lower.contains('png') || lower.endsWith('.png')) return '.png';
      if (lower.contains('webp') || lower.endsWith('.webp')) return '.webp';
      if (lower.contains('gif') || lower.endsWith('.gif')) return '.gif';
      if (lower.contains('heic') || lower.endsWith('.heic')) return '.heic';
      if (lower.contains('heif') || lower.endsWith('.heif')) return '.heif';
      if (lower.contains('jpeg') ||
          lower.contains('jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.jpg')) {
        return '.jpg';
      }
    }
    return '.jpg';
  }

  /// 重置为默认头像（漂泊者 / 星芒）。
  static Future<String> reset(WidgetRef ref) async {
    try {
      await ref.read(userAvatarProvider.notifier).reset();
      return '已恢复默认头像';
    } catch (e) {
      return '重置失败：$e';
    }
  }
}

/// 可点击的「我的头像」组件：点按弹出上传/重置菜单。
class TappableSelfAvatar extends ConsumerWidget {
  final double size;
  const TappableSelfAvatar({super.key, this.size = 56});

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload, color: AppColors.coolAccent),
              title: const Text(
                '上传自定义头像',
                style: TextStyle(color: AppColors.silver),
              ),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt, color: AppColors.steel),
              title: const Text(
                '恢复默认头像',
                style: TextStyle(color: AppColors.silver),
              ),
              onTap: () => Navigator.pop(ctx, 'reset'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    String hint;
    if (action == 'pick') {
      hint = await AvatarPicker.pickAndSet(ref);
    } else {
      hint = await AvatarPicker.reset(ref);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hint), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      onTap: () => _showMenu(context, ref),
      child: Stack(
        children: [
          SelfAvatar(size: size),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                size: 12,
                color: AppColors.coolAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
