import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'achievement_data.dart';
import 'achievement_view.dart';

/// 成就触发器服务：在应用各处调用，检查并触发成就解锁。
class AchievementTrigger {
  final WidgetRef ref;
  final BuildContext? context; // 可选：用于弹出解锁对话框

  AchievementTrigger(this.ref, {this.context});

  /// 触发"发送飞讯消息"成就。
  Future<void> onSendMessage({bool isEmoji = false}) async {
    await _check('feixun_sender_10');
    await _check('feixun_sender_100');
    if (isEmoji) {
      await _check('feixun_emoji_master');
    }
  }

  /// 触发"查看图鉴条目"成就。
  Future<void> onViewCodexEntry() async {
    await _check('codex_viewer_10');
    await _check('codex_viewer_50');
    await _check('codex_viewer_all');
  }

  /// 触发"收藏条目"成就。
  Future<void> onFavoriteEntry() async {
    await _check('collection_starter');
    await _check('collection_enthusiast');
    await _check('collection_master');
  }

  /// 触发"查看势力档案"成就。
  Future<void> onViewFaction() async {
    await _check('faction_explorer');
  }

  /// 触发"播放角色语音"成就。
  Future<void> onPlayVoice() async {
    await _check('voice_listener');
  }

  /// 触发"首次启动"成就（仅调用一次）。
  Future<void> onFirstLaunch() async {
    final notifier = ref.read(achievementProgressProvider.notifier);
    await notifier.unlock('first_login');
  }

  /// 触发"完善资料"成就（检查用户名片是否填写完整）。
  Future<void> checkProfileComplete(bool isComplete) async {
    if (isComplete) {
      final notifier = ref.read(achievementProgressProvider.notifier);
      await notifier.unlock('profile_complete');
    }
  }

  /// 触发"好感度升级"成就。
  Future<void> onAffectionLevelUp(int level) async {
    final notifier = ref.read(achievementProgressProvider.notifier);
    if (level >= 3) {
      final unlocked = await notifier.updateProgress('affection_level_3', level);
      if (unlocked && context != null && context!.mounted) {
        final achievement = kAchievements.firstWhere((a) => a.id == 'affection_level_3');
        showAchievementUnlockedDialog(context!, achievement);
      }
    }
    if (level >= 5) {
      final unlocked = await notifier.updateProgress('affection_level_5', level);
      if (unlocked && context != null && context!.mounted) {
        final achievement = kAchievements.firstWhere((a) => a.id == 'affection_level_5');
        showAchievementUnlockedDialog(context!, achievement);
      }
    }
  }

  /// 触发"每日签到"成就。
  Future<void> onDailyCheckIn(int consecutiveDays, int totalCheckIns) async {
    final notifier = ref.read(achievementProgressProvider.notifier);

    // 连续签到成就
    if (consecutiveDays >= 7) {
      final unlocked = await notifier.updateProgress('daily_checkin_7', consecutiveDays);
      if (unlocked && context != null && context!.mounted) {
        final achievement = kAchievements.firstWhere((a) => a.id == 'daily_checkin_7');
        showAchievementUnlockedDialog(context!, achievement);
      }
    }

    // 累计签到成就
    if (totalCheckIns >= 30) {
      final unlocked = await notifier.updateProgress('daily_checkin_30', totalCheckIns);
      if (unlocked && context != null && context!.mounted) {
        final achievement = kAchievements.firstWhere((a) => a.id == 'daily_checkin_30');
        showAchievementUnlockedDialog(context!, achievement);
      }
    }
  }

  /// 触发"UGC 创作"成就。
  Future<void> onCreateUGCScript(int totalScripts) async {
    final notifier = ref.read(achievementProgressProvider.notifier);

    if (totalScripts >= 1) {
      final unlocked = await notifier.updateProgress('ugc_creator', totalScripts);
      if (unlocked && context != null && context!.mounted) {
        final achievement = kAchievements.firstWhere((a) => a.id == 'ugc_creator');
        showAchievementUnlockedDialog(context!, achievement);
      }
    }

    if (totalScripts >= 5) {
      final unlocked = await notifier.updateProgress('ugc_master', totalScripts);
      if (unlocked && context != null && context!.mounted) {
        final achievement = kAchievements.firstWhere((a) => a.id == 'ugc_master');
        showAchievementUnlockedDialog(context!, achievement);
      }
    }
  }

  /// 内部方法：增量进度并检查解锁。
  Future<void> _check(String achievementId) async {
    final notifier = ref.read(achievementProgressProvider.notifier);
    final unlocked = await notifier.incrementProgress(achievementId);
    
    if (unlocked && context != null && context!.mounted) {
      final achievement = kAchievements.firstWhere((a) => a.id == achievementId);
      showAchievementUnlockedDialog(context!, achievement);
    }
  }
}
