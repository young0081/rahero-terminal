import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/effects/scanline_overlay.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../achievements/achievement_data.dart';
import '../achievements/achievement_view.dart';
import '../feixun/avatar_picker.dart';
import 'collection_data.dart';
import 'profile_data.dart';
import 'profile_edit_sheet.dart';

/// 个人信息页（「我的」）：本地名片 + 使用统计 + 收藏夹 + 成就系统。
/// 全部本地存储，无需联网。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final collection = ref.watch(collectionProvider);
    final achievements = ref.watch(achievementProgressProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      child: ListView(
        children: [
          // 移动端顶部已有 AppBar 显示"我的"，避免页内标题重复；
          // 桌面/平板用 NavigationRail 无 AppBar，故保留页内标题。
          if (!Responsive.isMobile(context)) ...[
            const Text('我的',
                style: TextStyle(
                    color: AppColors.silver,
                    fontSize: 22,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimens.gapLg),
          ],

          // —— 名片 ——
          TerminalPanel(
            glow: AppColors.glowBlue,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TappableSelfAvatar(size: 72),
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname.isEmpty ? '漂泊者' : profile.nickname,
                        style: const TextStyle(
                            color: AppColors.silver,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.signature.isEmpty
                            ? '（还没有签名，点右侧编辑）'
                            : profile.signature,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: AppDimens.gapSm),
                      Wrap(
                        spacing: AppDimens.gapSm,
                        runSpacing: 4,
                        children: [
                          if (profile.uid.isNotEmpty)
                            _Chip(label: 'UID ${profile.uid}'),
                          if (profile.region.isNotEmpty)
                            _Chip(label: profile.region),
                          if (profile.favoriteRole.isNotEmpty)
                            _Chip(label: '常用 ${profile.favoriteRole}'),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '编辑资料',
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.coolAccent),
                  onPressed: () => showProfileEditSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 使用统计 ——
          TerminalPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('使用统计',
                    style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppDimens.gapMd),
                Row(
                  children: [
                    _StatBox(
                        label: '已浏览条目',
                        value: '${collection.viewedCount}'),
                    const SizedBox(width: AppDimens.gapMd),
                    _StatBox(
                        label: '收藏条目',
                        value: '${collection.favoriteCount}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 成就系统预览 ——
          TerminalPanel(
            glow: AppColors.xingjuGlow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '成就系统',
                        style: TextStyle(
                          color: AppColors.silver,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAchievements(context),
                      child: const Text('查看全部'),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapSm),
                Text(
                  '已解锁 ${achievements.unlocked.length} / ${kAchievements.length} 项成就',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
                LinearProgressIndicator(
                  value: getAchievementCompletionPercent(achievements) / 100,
                  backgroundColor: AppColors.border,
                  color: AppColors.xingjuGreen,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // —— 收藏夹 ——
          _FavoritesPanel(favorites: collection.favorites),
        ],
      ),
    );
  }

  void _showAchievements(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Text('成就系统'),
          ),
          body: const AchievementView(),
        ),
      ),
    );
  }
}

/// 小信息标签。
class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.steel, fontSize: 12)),
    );
  }
}

/// 统计数字盒。
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.gapMd),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.coolAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// 收藏夹面板：列出收藏的条目名（key 形如 category:entryId，这里显示分类+计数）。
class _FavoritesPanel extends StatelessWidget {
  final Set<String> favorites;
  const _FavoritesPanel({required this.favorites});

  @override
  Widget build(BuildContext context) {
    // 按分类聚合计数。
    final byCat = <String, int>{};
    for (final k in favorites) {
      final cat = k.contains(':') ? k.split(':').first : '其他';
      byCat[cat] = (byCat[cat] ?? 0) + 1;
    }
    const catLabel = {
      'resonator': '共鸣者',
      'weapon': '武器',
      'echo': '声骸',
    };

    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的收藏',
              style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.gapXs),
          if (favorites.isEmpty)
            const Text('还没有收藏。在图鉴里点开条目，右上角心形即可收藏。',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.gapSm),
              child: Wrap(
                spacing: AppDimens.gapSm,
                runSpacing: AppDimens.gapSm,
                children: [
                  for (final e in byCat.entries)
                    _Chip(label: '${catLabel[e.key] ?? e.key} ${e.value}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
