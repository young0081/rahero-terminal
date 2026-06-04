import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';

/// 成就定义：id / 名称 / 描述 / 解锁条件 / 图标。
class Achievement {
  final String id;
  final String name;
  final String description;
  final String category; // 分类：探索/飞讯/图鉴/收藏/系统
  final int target; // 目标值（如发送 100 条消息）
  final String icon; // 图标 emoji 或 icon name

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.target,
    this.icon = '🏆',
  });
}

/// 用户成就进度：已解锁的成就 + 各成就的当前进度。
class AchievementProgress {
  final Set<String> unlocked; // 已解锁的成就 id
  final Map<String, int> progress; // 各成就的当前进度值

  const AchievementProgress({
    this.unlocked = const {},
    this.progress = const {},
  });

  AchievementProgress copyWith({
    Set<String>? unlocked,
    Map<String, int>? progress,
  }) =>
      AchievementProgress(
        unlocked: unlocked ?? this.unlocked,
        progress: progress ?? this.progress,
      );

  Map<String, dynamic> toJson() => {
        'unlocked': unlocked.toList(),
        'progress': progress,
      };

  factory AchievementProgress.fromJson(Map<String, dynamic> j) {
    final unlockedList = (j['unlocked'] as List?)?.cast<String>() ?? [];
    final progressMap =
        (j['progress'] as Map?)?.map((k, v) => MapEntry(k.toString(), v as int)) ?? {};
    return AchievementProgress(
      unlocked: Set<String>.from(unlockedList),
      progress: Map<String, int>.from(progressMap),
    );
  }

  /// 获取某个成就的当前进度（默认 0）。
  int getProgress(String id) => progress[id] ?? 0;

  /// 检查某个成就是否已解锁。
  bool isUnlocked(String id) => unlocked.contains(id);
}

/// 内置成就列表。
const List<Achievement> kAchievements = [
  // 飞讯类
  Achievement(
    id: 'feixun_sender_10',
    name: '初次联络',
    description: '发送 10 条飞讯消息',
    category: '飞讯',
    target: 10,
    icon: '💬',
  ),
  Achievement(
    id: 'feixun_sender_100',
    name: '飞讯达人',
    description: '发送 100 条飞讯消息',
    category: '飞讯',
    target: 100,
    icon: '📱',
  ),
  Achievement(
    id: 'feixun_emoji_master',
    name: '表情包收藏家',
    description: '发送 30 条表情消息',
    category: '飞讯',
    target: 30,
    icon: '😊',
  ),

  // 图鉴类
  Achievement(
    id: 'codex_viewer_10',
    name: '资料初探',
    description: '查看 10 个图鉴条目',
    category: '图鉴',
    target: 10,
    icon: '📖',
  ),
  Achievement(
    id: 'codex_viewer_50',
    name: '资料学者',
    description: '查看 50 个图鉴条目',
    category: '图鉴',
    target: 50,
    icon: '📚',
  ),
  Achievement(
    id: 'codex_viewer_all',
    name: '百科全书',
    description: '查看 100 个图鉴条目',
    category: '图鉴',
    target: 100,
    icon: '🎓',
  ),

  // 收藏类
  Achievement(
    id: 'collection_starter',
    name: '收藏起步',
    description: '收藏 5 个条目',
    category: '收藏',
    target: 5,
    icon: '⭐',
  ),
  Achievement(
    id: 'collection_enthusiast',
    name: '收藏爱好者',
    description: '收藏 20 个条目',
    category: '收藏',
    target: 20,
    icon: '🌟',
  ),
  Achievement(
    id: 'collection_master',
    name: '收藏大师',
    description: '收藏 50 个条目',
    category: '收藏',
    target: 50,
    icon: '✨',
  ),

  // 系统类
  Achievement(
    id: 'first_login',
    name: '初次启动',
    description: '首次打开拉海洛终端',
    category: '系统',
    target: 1,
    icon: '🚀',
  ),
  Achievement(
    id: 'profile_complete',
    name: '完善资料',
    description: '填写完整个人名片信息',
    category: '系统',
    target: 1,
    icon: '👤',
  ),
  Achievement(
    id: 'daily_user_7',
    name: '每日登录',
    description: '连续登录 7 天',
    category: '系统',
    target: 7,
    icon: '📅',
  ),

  // 探索类
  Achievement(
    id: 'faction_explorer',
    name: '势力观察者',
    description: '查看所有势力档案',
    category: '探索',
    target: 16,
    icon: '🔍',
  ),
  Achievement(
    id: 'voice_listener',
    name: '倾听者',
    description: '播放 20 条角色语音',
    category: '探索',
    target: 20,
    icon: '🎵',
  ),

  // 好感度类
  Achievement(
    id: 'affection_level_3',
    name: '建立信任',
    description: '与任意角色好感度达到「信任」',
    category: '飞讯',
    target: 3,
    icon: '💙',
  ),
  Achievement(
    id: 'affection_level_5',
    name: '挚友之证',
    description: '与任意角色好感度达到「挚友」',
    category: '飞讯',
    target: 5,
    icon: '💖',
  ),

  // UGC 创作类
  Achievement(
    id: 'ugc_creator',
    name: '剧本作者',
    description: '创作第一个 UGC 剧本',
    category: '探索',
    target: 1,
    icon: '✍️',
  ),
  Achievement(
    id: 'ugc_master',
    name: '创作大师',
    description: '创作 5 个 UGC 剧本',
    category: '探索',
    target: 5,
    icon: '📝',
  ),
];

/// 成就进度状态管理。
class AchievementProgressNotifier extends Notifier<AchievementProgress> {
  static const _key = 'achievement_progress';

  @override
  AchievementProgress build() {
    final raw = AppStorage.getSetting<String>(_key, '');
    if (raw.isEmpty) return const AchievementProgress();
    try {
      return AchievementProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AchievementProgress();
    }
  }

  /// 更新某个成就的进度，达到目标时自动解锁。
  Future<bool> updateProgress(String achievementId, int newProgress) async {
    final achievement = kAchievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw ArgumentError('Unknown achievement: $achievementId'),
    );

    final current = state.getProgress(achievementId);
    if (newProgress <= current) return false; // 进度未增长

    final newProgressMap = Map<String, int>.from(state.progress);
    newProgressMap[achievementId] = newProgress;

    final newUnlocked = Set<String>.from(state.unlocked);
    final justUnlocked = !state.isUnlocked(achievementId) && newProgress >= achievement.target;
    if (justUnlocked) {
      newUnlocked.add(achievementId);
    }

    state = AchievementProgress(unlocked: newUnlocked, progress: newProgressMap);
    await _save();
    return justUnlocked;
  }

  /// 增量更新进度（当前值 +1）。
  Future<bool> incrementProgress(String achievementId) async {
    final current = state.getProgress(achievementId);
    return updateProgress(achievementId, current + 1);
  }

  /// 手动解锁成就（用于一次性触发的成就，如"首次启动"）。
  Future<void> unlock(String achievementId) async {
    if (state.isUnlocked(achievementId)) return;
    final newUnlocked = Set<String>.from(state.unlocked)..add(achievementId);
    state = state.copyWith(unlocked: newUnlocked);
    await _save();
  }

  Future<void> _save() async {
    await AppStorage.setSetting(_key, jsonEncode(state.toJson()));
  }
}

final achievementProgressProvider =
    NotifierProvider<AchievementProgressNotifier, AchievementProgress>(
  AchievementProgressNotifier.new,
);

/// 辅助方法：获取成就完成百分比（已解锁数 / 总数）。
int getAchievementCompletionPercent(AchievementProgress progress) {
  if (kAchievements.isEmpty) return 0;
  return (progress.unlocked.length * 100 / kAchievements.length).round();
}
