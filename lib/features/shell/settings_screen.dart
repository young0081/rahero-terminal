import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/effects/scanline_overlay.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../codex/wiki_providers.dart';
import '../codex/wiki_sync.dart';
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

  Future<void> _pickAvatar() async {
    setState(() {
      _avatarWorking = true;
      _avatarHint = null;
    });
    final hint = await AvatarPicker.pickAndSet(ref);
    if (mounted) {
      setState(() {
        _avatarHint = hint;
        _avatarWorking = false;
      });
    }
  }

  Future<void> _resetAvatar() async {
    setState(() {
      _avatarWorking = true;
      _avatarHint = null;
    });
    final hint = await AvatarPicker.reset(ref);
    if (mounted) {
      setState(() {
        _avatarHint = hint;
        _avatarWorking = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _working = true;
      _hint = null;
    });
    try {
      await ref.read(assetServiceProvider).clearCache();
      await AppStorage.clearCodex();
      setState(() => _hint = '缓存已清空。下次启动将重新下载资源。');
    } catch (e) {
      setState(() => _hint = '清空失败：$e');
    } finally {
      _refreshImageCaches();
      if (mounted) setState(() => _working = false);
    }
  }

  void _refreshImageCaches() {
    ref.invalidate(wikiImageProvider);
    ref.invalidate(wikiListProvider);
    ref.invalidate(wikiDetailProvider);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _redownload() async {
    setState(() {
      _working = true;
      _hint = null;
    });
    try {
      final service = ref.read(assetServiceProvider);
      await service.clearCache();
      await for (final _ in service.syncAll(force: true)) {
        // 逐项进行；此处只等待完成。
      }
      setState(() => _hint = '资源重新下载完成。');
    } catch (e) {
      setState(() => _hint = '重新下载遇到问题：$e（可稍后重试，期间使用占位图）');
    } finally {
      _refreshImageCaches();
      if (mounted) setState(() => _working = false);
    }
  }

  void _showOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _syncPanel() {
    final sync = ref.watch(wikiSyncProvider);
    final notifier = ref.read(wikiSyncProvider.notifier);
    return TerminalPanel(
      glow: AppColors.glowBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('图鉴更新',
              style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.gapXs),
          const Text(
            '程序会自动从库街区检测新角色/武器/声骸并同步内容，新素材按需下载。'
            '仅在程序运行时检查，关闭期间的更新会在下次启动补上。',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppDimens.gapMd),
          const Text('检查频率',
              style: TextStyle(color: AppColors.steel, fontSize: 13)),
          const SizedBox(height: AppDimens.gapXs),
          Wrap(
            spacing: AppDimens.gapSm,
            runSpacing: AppDimens.gapSm,
            children: [
              for (final m in WikiSyncMode.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: sync.mode == m,
                  selectedColor: AppColors.coolGlow,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: sync.mode == m
                        ? AppColors.coolAccent
                        : AppColors.textMuted,
                    fontSize: 12,
                  ),
                  onSelected: (_) => notifier.setMode(m),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Row(
            children: [
              FilledButton.icon(
                onPressed: sync.checking ? null : () => notifier.checkNow(),
                icon: const Icon(Icons.sync),
                label: const Text('立即检查更新'),
              ),
              const SizedBox(width: AppDimens.gapMd),
              if (sync.checking)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(_syncStatusText(sync),
              style: const TextStyle(
                  color: AppColors.coolAccent, fontSize: 13)),
        ],
      ),
    );
  }

  String _syncStatusText(WikiSyncState s) {
    if (s.checking) return '正在检查…';
    final t = s.lastSync;
    final when = t == null ? '尚未检查' : '上次检查：${_fmtTime(t)}';
    final r = s.lastResult;
    if (r == null) return when;
    if (!r.ok) return '$when（联网失败，使用本地缓存）';
    if (r.hasChanges) {
      final parts = <String>[];
      if (r.newCount > 0) parts.add('新增 ${r.newCount}');
      if (r.updatedCount > 0) parts.add('更新 ${r.updatedCount}');
      return '$when · 发现${parts.join("、")}，已同步';
    }
    return '$when · 已是最新';
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final themeColors = getThemeColors(currentTheme);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      child: ListView(
        children: [
          const Text('设置',
              style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 22,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.gapLg),

          // —— UGC 剧本 ——
          TerminalPanel(
            glow: Colors.purpleAccent.withValues(alpha: 0.3),
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
            glow: AppColors.xingjuGlow,
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
                  '了解终端的主要功能和使用方式。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppDimens.gapMd),
                FilledButton.icon(
                  onPressed: _showOnboarding,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('查看引导'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 主题切换 ——
          TerminalPanel(
            glow: themeColors.primaryGlow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主题外观',
                    style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimens.gapXs),
                Text(
                  '当前主题：${currentTheme.label}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppDimens.gapMd),
                FilledButton.icon(
                  onPressed: () => showThemeSelector(context),
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('切换主题'),
                  style: FilledButton.styleFrom(
                    backgroundColor: themeColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 头像设置 ——
          TerminalPanel(
            glow: AppColors.glowBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('我的头像',
                    style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimens.gapXs),
                const Text(
                  '飞讯中「我」发出的消息使用此头像。未设置时使用漂泊者头像（首次运行从库街区下载）。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppDimens.gapMd),
                Row(
                  children: [
                    const SelfAvatar(size: 56),
                    const SizedBox(width: AppDimens.gapMd),
                    Expanded(
                      child: Wrap(
                        spacing: AppDimens.gapSm,
                        runSpacing: AppDimens.gapSm,
                        children: [
                          FilledButton.icon(
                            onPressed: _avatarWorking
                                ? null
                                : () => _pickAvatar(),
                            icon: const Icon(Icons.upload),
                            label: const Text('上传头像'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _avatarWorking
                                ? null
                                : () => _resetAvatar(),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_avatarHint != null) ...[
                  const SizedBox(height: AppDimens.gapSm),
                  Text(_avatarHint!,
                      style: const TextStyle(
                          color: AppColors.coolAccent, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 资源缓存 ——
          TerminalPanel(
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
                  '势力图标等资源会在首次运行时从库街区下载并缓存在本地，离线可用。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppDimens.gapMd),
                Wrap(
                  spacing: AppDimens.gapSm,
                  runSpacing: AppDimens.gapSm,
                  children: [
                    FilledButton.icon(
                      onPressed: _working ? null : _redownload,
                      icon: const Icon(Icons.download),
                      label: const Text('重新下载资源'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working ? null : _clearCache,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('清空缓存'),
                    ),
                  ],
                ),
                if (_working) ...[
                  const SizedBox(height: AppDimens.gapMd),
                  const LinearProgressIndicator(),
                ],
                if (_hint != null) ...[
                  const SizedBox(height: AppDimens.gapSm),
                  Text(_hint!,
                      style: const TextStyle(
                          color: AppColors.coolAccent, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 图鉴更新 ——
          _syncPanel(),
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
    );
  }
}
