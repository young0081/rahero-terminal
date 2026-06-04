import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';

/// 好感度等级配置
class AffectionLevel {
  final int level;
  final String title;
  final int requiredPoints;
  final String description;

  const AffectionLevel({
    required this.level,
    required this.title,
    required this.requiredPoints,
    required this.description,
  });
}

/// 好感度等级表
const affectionLevels = [
  AffectionLevel(level: 0, title: '陌生', requiredPoints: 0, description: '刚刚认识'),
  AffectionLevel(level: 1, title: '熟识', requiredPoints: 10, description: '开始熟悉'),
  AffectionLevel(level: 2, title: '友好', requiredPoints: 30, description: '成为了朋友'),
  AffectionLevel(level: 3, title: '信任', requiredPoints: 60, description: '彼此信任'),
  AffectionLevel(level: 4, title: '亲密', requiredPoints: 100, description: '无话不谈'),
  AffectionLevel(level: 5, title: '挚友', requiredPoints: 150, description: '最重要的伙伴'),
];

/// 好感度数据
class AffectionData {
  final String contactId;
  final int points; // 当前好感度点数
  final int totalInteractions; // 总互动次数
  final DateTime lastInteraction; // 最后互动时间
  final Map<String, int> unlockedStories; // 已解锁的特殊剧情 {storyId: unlockedAt}

  const AffectionData({
    required this.contactId,
    this.points = 0,
    this.totalInteractions = 0,
    required this.lastInteraction,
    this.unlockedStories = const {},
  });

  /// 获取当前等级
  AffectionLevel get level {
    for (int i = affectionLevels.length - 1; i >= 0; i--) {
      if (points >= affectionLevels[i].requiredPoints) {
        return affectionLevels[i];
      }
    }
    return affectionLevels[0];
  }

  /// 获取下一级
  AffectionLevel? get nextLevel {
    final currentIdx = affectionLevels.indexOf(level);
    if (currentIdx < affectionLevels.length - 1) {
      return affectionLevels[currentIdx + 1];
    }
    return null;
  }

  /// 距离下一级的进度（0.0 - 1.0）
  double get progressToNext {
    final next = nextLevel;
    if (next == null) return 1.0;
    final current = level;
    final range = next.requiredPoints - current.requiredPoints;
    final progress = points - current.requiredPoints;
    return (progress / range).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'points': points,
        'totalInteractions': totalInteractions,
        'lastInteraction': lastInteraction.toIso8601String(),
        'unlockedStories': unlockedStories,
      };

  factory AffectionData.fromJson(Map<String, dynamic> j) => AffectionData(
        contactId: j['contactId'] as String,
        points: j['points'] as int? ?? 0,
        totalInteractions: j['totalInteractions'] as int? ?? 0,
        lastInteraction: DateTime.parse(j['lastInteraction'] as String),
        unlockedStories: Map<String, int>.from(j['unlockedStories'] as Map? ?? {}),
      );

  AffectionData copyWith({
    int? points,
    int? totalInteractions,
    DateTime? lastInteraction,
    Map<String, int>? unlockedStories,
  }) =>
      AffectionData(
        contactId: contactId,
        points: points ?? this.points,
        totalInteractions: totalInteractions ?? this.totalInteractions,
        lastInteraction: lastInteraction ?? this.lastInteraction,
        unlockedStories: unlockedStories ?? this.unlockedStories,
      );
}

/// 好感度服务：管理所有联系人的好感度数据
class AffectionService {
  static const _storageKey = 'feixun_affection';
  final Map<String, AffectionData> _cache = {};

  /// 获取某个联系人的好感度数据
  Future<AffectionData> get(String contactId) async {
    if (_cache.containsKey(contactId)) {
      return _cache[contactId]!;
    }

    final jsonStr = AppStorage.getSetting<String>(_storageKey, '{}');
    final all = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (all.containsKey(contactId)) {
      final data = AffectionData.fromJson(all[contactId] as Map<String, dynamic>);
      _cache[contactId] = data;
      return data;
    }

    // 初始化新联系人
    final newData = AffectionData(
      contactId: contactId,
      lastInteraction: DateTime.now(),
    );
    _cache[contactId] = newData;
    return newData;
  }

  /// 增加好感度（发送消息、查看对话等）
  Future<AffectionData> addPoints(String contactId, int points) async {
    final current = await get(contactId);
    final updated = current.copyWith(
      points: (current.points + points).clamp(0, 999),
      totalInteractions: current.totalInteractions + 1,
      lastInteraction: DateTime.now(),
    );
    await _save(updated);
    return updated;
  }

  /// 解锁特殊剧情
  Future<void> unlockStory(String contactId, String storyId) async {
    final current = await get(contactId);
    final stories = Map<String, int>.from(current.unlockedStories);
    stories[storyId] = DateTime.now().millisecondsSinceEpoch;
    final updated = current.copyWith(unlockedStories: stories);
    await _save(updated);
  }

  /// 检查是否已解锁剧情
  Future<bool> isStoryUnlocked(String contactId, String storyId) async {
    final data = await get(contactId);
    return data.unlockedStories.containsKey(storyId);
  }

  Future<void> _save(AffectionData data) async {
    _cache[data.contactId] = data;

    final jsonStr = AppStorage.getSetting<String>(_storageKey, '{}');
    final all = jsonDecode(jsonStr) as Map<String, dynamic>;
    all[data.contactId] = data.toJson();

    await AppStorage.setSetting(_storageKey, jsonEncode(all));
  }

  /// 获取所有好感度数据（用于统计）
  Future<Map<String, AffectionData>> getAll() async {
    final jsonStr = AppStorage.getSetting<String>(_storageKey, '{}');
    final all = jsonDecode(jsonStr) as Map<String, dynamic>;
    return all.map((k, v) => MapEntry(k, AffectionData.fromJson(v as Map<String, dynamic>)));
  }
}

/// 好感度服务单例
final affectionServiceProvider = Provider<AffectionService>((ref) => AffectionService());

/// 某个联系人的好感度数据 Provider
final contactAffectionProvider = FutureProvider.family<AffectionData, String>((ref, contactId) async {
  final service = ref.watch(affectionServiceProvider);
  return service.get(contactId);
});
