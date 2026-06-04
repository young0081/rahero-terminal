import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/effects/scanline_overlay.dart';
import '../../core/theme/app_theme.dart';
import 'achievement_data.dart';

/// 成就系统界面：徽章墙 + 进度追踪。
class AchievementView extends ConsumerWidget {
  const AchievementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(achievementProgressProvider);
    final completionPercent = getAchievementCompletionPercent(progress);

    // 按分类分组
    final byCategory = <String, List<Achievement>>{};
    for (final a in kAchievements) {
      byCategory.putIfAbsent(a.category, () => []).add(a);
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimens.gapLg),
      child: ListView(
        children: [
          // 总体完成度
          TerminalPanel(
            glow: AppColors.glowBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '成就系统',
                  style: TextStyle(
                    color: AppColors.silver,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.gapSm),
                Text(
                  '已解锁 ${progress.unlocked.length} / ${kAchievements.length} 项成就',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: completionPercent / 100,
                        backgroundColor: AppColors.border,
                        color: AppColors.coolAccent,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: AppDimens.gapMd),
                    Text(
                      '$completionPercent%',
                      style: const TextStyle(
                        color: AppColors.coolAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gapLg),

          // 按分类列出成就
          for (final category in byCategory.keys) ...[
            Text(
              category,
              style: const TextStyle(
                color: AppColors.steel,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.gapSm),
            ...byCategory[category]!.map((a) => _AchievementCard(
                  achievement: a,
                  progress: progress,
                )),
            const SizedBox(height: AppDimens.gapLg),
          ],
        ],
      ),
    );
  }
}

/// 单个成就卡片：图标 + 名称 + 描述 + 进度条。
class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final AchievementProgress progress;

  const _AchievementCard({
    required this.achievement,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.isUnlocked(achievement.id);
    final current = progress.getProgress(achievement.id);
    final percent = achievement.target > 0
        ? (current / achievement.target).clamp(0.0, 1.0)
        : (unlocked ? 1.0 : 0.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: TerminalPanel(
        child: Row(
          children: [
            // 图标区
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: unlocked ? AppColors.coolAccent.withValues(alpha: 0.15) : AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                border: Border.all(
                  color: unlocked ? AppColors.coolAccent : AppColors.border,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: TextStyle(
                    fontSize: 28,
                    color: unlocked ? null : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.gapMd),

            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.name,
                          style: TextStyle(
                            color: unlocked ? AppColors.coolAccent : AppColors.silver,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unlocked)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.coolAccent,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapSm),

                  // 进度条（未解锁时显示）
                  if (!unlocked) ...[
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: AppColors.border,
                            color: AppColors.steel,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),
                        Text(
                          '$current / ${achievement.target}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      '已解锁',
                      style: TextStyle(
                        color: AppColors.coolAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 成就解锁弹窗（当新成就解锁时显示）。
void showAchievementUnlockedDialog(BuildContext context, Achievement achievement) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        side: const BorderSide(color: AppColors.coolAccent, width: 2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            achievement.icon,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: AppDimens.gapMd),
          const Text(
            '🎉 成就解锁',
            style: TextStyle(
              color: AppColors.coolAccent,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(
            achievement.name,
            style: const TextStyle(
              color: AppColors.silver,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
