import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/effects/scanline_overlay.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../codex/wiki_providers.dart';
import '../codex/wiki_sync.dart';
import '../daily/daily_checkin_screen.dart';
import '../feixun/avatar_picker.dart';
import '../feixun/feixun_avatar.dart';
import '../feixun/ugc_script_list.dart';
import '../onboarding/onboarding_screen.dart';
import '../provisioning/asset_providers.dart';
import '../theming/theme_manager.dart';

/// 设置页：资源缓存管理（重新下载 / 清空缓存）、新手引导、主题切换等。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _working = false;
  String? _hint;

  bool _avatarWorking = false;
  String? _avatarHint;

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('清空缓存', style: TextStyle(color: AppColors.silver)),
        content: const Text(
          '将清除所有图标、视频、图鉴图片等缓存文件（约数百 MB），'
          '下次启动会重新下载。不影响用户数据（飞讯进度、收藏、设置等）。',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _working = true;
      _hint = '正在清理缓存...';
    });

    await AppStorage.clearAssetCache();
    ref.invalidate(assetManifestProvider);
    ref.invalidate(assetCachedStatusProvider);

    if (mounted) {
      setState(() {
        _working = false;
        _hint = '缓存已清空，下次启动将重新下载资源';
      });
    }
  }

  Future<void> _redownload() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('重新下载资源', style: TextStyle(color: AppColors.silver)),
        content: const Text(
          '将重新校验并下载所有资源文件（仅下载缺失或损坏的部分）。',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新下载', style: TextStyle(color: AppColors.coolAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _working = true;
      _hint = '正在校验并下载...';
    });

    ref.invalidate(assetManifestProvider);
    ref.invalidate(assetCachedStatusProvider);

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _working = false;
        _hint = '下载任务已启动，刷新本页或重启应用查看进度';
      });
    }
  }

  Future<void> _clearCodexCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('清空图鉴缓存', style: TextStyle(color: AppColors.silver)),
        content: const Text(
          '将清除图鉴内容（共鸣者/武器/声骸）的缓存数据和图片，'
          '下次打开图鉴会重新从库街区拉取。',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _working = true;
      _hint = '正在清理图鉴缓存...';
    });

    await AppStorage.clearCodex();
    ref.invalidate(wikiListProvider);
    ref.invalidate(wikiDetailProvider);
    ref.invalidate(wikiImageProvider);

    if (mounted) {
      setState(() {
        _working = false;
        _hint = '图鉴缓存已清空';
      });
    }
  }

  Future<void> _refreshCodex() async {
    setState(() {
      _working = true;
      _hint = '正在刷新图鉴...';
    });

    ref.invalidate(wikiListProvider);
    ref.invalidate(wikiDetailProvider);

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _working = false;
        _hint = '图鉴数据已刷新';
      });
    }
  }

  void _changeAvatar() async {
    setState(() {
      _avatarWorking = true;
      _avatarHint = null;
    });

    final result = await showDialog<String>(
      context: context,
      builder: (context) => const AvatarPickerDialog(),
    );

    if (result != null && mounted) {
      await AppStorage.setSetting('feixun_my_avatar', result);
      setState(() {
        _avatarHint = '头像已更换';
      });
    }

    if (mounted) {
      setState(() => _avatarWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = AppStorage.getSetting<String>('feixun_my_avatar', 'avatar_漂泊者');
    final syncMode = ref.watch(wikiAutoSyncModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.gapMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // —— 每日祝福 ——
          TerminalPanel(
            glow: Colors.purpleAccent.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('每日祝福',
                    style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimens.gapXs),
                const Text(
                  '每天获取一句《鸣潮》角色语录，纯粹的情感互动，不涉及任何积分。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppDimens.gapMd),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DailyCheckInScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('查看祝福'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— UGC 剧本 ——
          TerminalPanel(
            glow: Colors.deepPurpleAccent.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UGC 剧本',
                    style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimens.gapXs),
                const Text(
                  '创作你自己的飞讯对话剧本，编写角色间的互动故事，还可以导出分享给其他人。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppDimens.gapMd),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UGCScriptListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('管理剧本'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

            // —— 新手引导 ——
            TerminalPanel(
              glow: AppColors.glowCyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('新手引导',
                      style: TextStyle(
                          color: AppColors.silver,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppDimens.gapXs),
                  const Text(
                    '查看应用功能介绍和使用指南。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('查看引导'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coolAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            // —— 主题切换 ——
            TerminalPanel(
              glow: AppColors.glowGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('主题切换',
                      style: TextStyle(
                          color: AppColors.silver,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppDimens.gapXs),
                  const Text(
                    '切换应用配色主题，选择你喜欢的风格。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ThemeManagerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.palette),
                    label: const Text('选择主题'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            // —— 飞讯头像 ——
            TerminalPanel(
              glow: AppColors.glowGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('我的头像',
                          style: TextStyle(
                              color: AppColors.silver,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      FeixunAvatar(assetId: currentAvatar, label: '我', size: 32),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapXs),
                  const Text(
                    '在飞讯对话中显示的头像（从漂泊者、安可、秧秧三选一）。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  if (_avatarHint != null) ...[
                    const SizedBox(height: AppDimens.gapXs),
                    Text(_avatarHint!, style: const TextStyle(color: AppColors.success, fontSize: 12)),
                  ],
                  const SizedBox(height: AppDimens.gapMd),
                  FilledButton.icon(
                    onPressed: _avatarWorking ? null : _changeAvatar,
                    icon: _avatarWorking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                        : const Icon(Icons.face),
                    label: const Text('更换头像'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.coolAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            // —— 资源缓存 ——
            TerminalPanel(
              glow: AppColors.glowCyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('资源缓存',
                      style: TextStyle(
                          color: AppColors.silver,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppDimens.gapXs),
                  const Text(
                    '应用图标、视频等资源文件的本地缓存管理。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  if (_hint != null) ...[
                    const SizedBox(height: AppDimens.gapXs),
                    Text(_hint!, style: const TextStyle(color: AppColors.success, fontSize: 12)),
                  ],
                  const SizedBox(height: AppDimens.gapMd),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _working ? null : _redownload,
                        icon: _working
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                            : const Icon(Icons.download),
                        label: const Text('重新下载'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.coolAccent),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _clearCache,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('清空缓存'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            // —— 图鉴缓存 ——
            TerminalPanel(
              glow: AppColors.glowBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('图鉴缓存',
                          style: TextStyle(
                              color: AppColors.silver,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coolAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                        child: Text(
                          _getSyncModeText(syncMode),
                          style: const TextStyle(color: AppColors.coolAccent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapXs),
                  const Text(
                    '共鸣者/武器/声骸等图鉴内容，实时从库街区 wiki 拉取。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _working ? null : _refreshCodex,
                        icon: _working
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                            : const Icon(Icons.refresh),
                        label: const Text('刷新图鉴'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.coolAccent),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _clearCodexCache,
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('清空图鉴缓存'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _changeSyncMode(context, ref),
                        icon: const Icon(Icons.schedule),
                        label: const Text('修改自动更新'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),

            // —— 关于 ——
            const TerminalPanel(
              glow: AppColors.glowBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('关于',
                      style: TextStyle(
                          color: AppColors.silver,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: AppDimens.gapXs),
                  Text(
                    '拉海洛终端 · 星炬学院终端复刻\n'
                    '《鸣潮》同人作品，开源，非官方。\n'
                    '受版权保护的图标/视频不随源码分发，由本程序运行时下载。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSyncModeText(WikiAutoSyncMode mode) {
    switch (mode) {
      case WikiAutoSyncMode.onLaunchOnly:
        return '仅启动时';
      case WikiAutoSyncMode.daily:
        return '每天凌晨4点';
      case WikiAutoSyncMode.hourly:
        return '每小时';
      case WikiAutoSyncMode.everyMinute:
        return '每分钟';
    }
  }

  Future<void> _changeSyncMode(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<WikiAutoSyncMode>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('图鉴自动更新频率', style: TextStyle(color: AppColors.silver)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in WikiAutoSyncMode.values)
              RadioListTile<WikiAutoSyncMode>(
                value: mode,
                groupValue: ref.read(wikiAutoSyncModeProvider),
                title: Text(_getSyncModeText(mode), style: const TextStyle(color: AppColors.silver)),
                onChanged: (v) => Navigator.of(context).pop(v),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );

    if (result != null) {
      await AppStorage.setSetting('wiki_auto_sync_mode', result.index);
      ref.invalidate(wikiAutoSyncModeProvider);
    }
  }
}
