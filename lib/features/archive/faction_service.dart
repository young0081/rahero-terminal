import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';
import '../codex/wiki_models.dart';
import 'moegirl_wiki_client.dart';

/// 一个势力档案条目。
class FactionEntry {
  final String assetId; // 本地动态 LOGO 资源 id（faction_xxx）
  final String name; // 展示名
  final String moegirlName; // 萌娘百科词条名（用于获取详情）
  final bool hasLocalAsset; // 是否有本地动态 LOGO 资源

  const FactionEntry({
    required this.assetId,
    required this.name,
    String? moegirlName,
    this.hasLocalAsset = true,
  }) : moegirlName = moegirlName ?? name;
}

/// 势力详情
class FactionDetail {
  final String name;
  final String? summary; // 简介（从萌娘百科获取）
  final String? fullContent; // 完整HTML内容
  final String story; // 故事简介（兼容原有结构）
  final List<WikiSection> sections; // 兼容原有结构
  final List<String> infoLines; // 信息行（兼容原有结构）
  final DateTime? lastUpdate;

  const FactionDetail({
    required this.name,
    this.summary,
    this.fullContent,
    this.story = '',
    this.sections = const [],
    this.infoLines = const [],
    this.lastUpdate,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'summary': summary,
        'fullContent': fullContent,
        'story': story,
        'sections': sections.map((s) => s.toJson()).toList(),
        'infoLines': infoLines,
        'lastUpdate': lastUpdate?.toIso8601String(),
      };

  factory FactionDetail.fromJson(Map<String, dynamic> json) => FactionDetail(
        name: json['name'] as String,
        summary: json['summary'] as String?,
        fullContent: json['fullContent'] as String?,
        story: json['story'] as String? ?? '',
        sections: (json['sections'] as List?)
                ?.map((s) => WikiSection.fromCache(s as Map<String, dynamic>))
                .toList() ??
            [],
        infoLines: (json['infoLines'] as List?)?.map((e) => e.toString()).toList() ?? [],
        lastUpdate: json['lastUpdate'] != null ? DateTime.parse(json['lastUpdate'] as String) : null,
      );

  /// 从萌娘百科数据创建（自动生成sections）
  factory FactionDetail.fromMoegirl({
    required String name,
    String? summary,
    String? fullContent,
  }) {
    final sections = <WikiSection>[];
    final infoLines = <String>['数据来源：萌娘百科'];

    // 如果有摘要，创建简介section
    if (summary != null && summary.isNotEmpty) {
      sections.add(WikiSection(
        title: '简介',
        blocks: [
          WikiBlock.text(summary),
        ],
      ));
    }

    // 如果有完整内容但没有摘要，从HTML提取文本
    if (sections.isEmpty && fullContent != null && fullContent.isNotEmpty) {
      // 简单提取：去掉HTML标签
      final plainText = _stripHtmlTags(fullContent);
      if (plainText.isNotEmpty) {
        sections.add(WikiSection(
          title: '详情',
          blocks: [
            WikiBlock.text(plainText.length > 500 ? plainText.substring(0, 500) + '...' : plainText),
          ],
        ));
      }
    }

    return FactionDetail(
      name: name,
      summary: summary,
      fullContent: fullContent,
      story: summary ?? '', // story使用summary
      sections: sections,
      infoLines: infoLines,
      lastUpdate: DateTime.now(),
    );
  }

  /// 简单去除HTML标签
  static String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // 去除标签
        .replaceAll(RegExp(r'\s+'), ' ') // 合并空白
        .trim();
  }
}

/// 势力列表拉取结果。
class FactionListResult {
  final List<FactionEntry> entries;
  final String? error;
  final DateTime? lastUpdate;
  const FactionListResult({
    required this.entries,
    this.error,
    this.lastUpdate,
  });
}

/// 势力档案服务（从萌娘百科获取）。
class FactionService {
  FactionService._();
  static final FactionService instance = FactionService._();

  final MoegirlWikiClient _client = MoegirlWikiClient();

  /// 本地内置势力列表（有动态 LOGO 的）。
  static const List<FactionEntry> _localFactions = [
    FactionEntry(assetId: 'faction_xingju', name: '星炬学院', moegirlName: '星炬学院'),
    FactionEntry(assetId: 'faction_shenkong', name: '深空联合', moegirlName: '深空联合'),
    FactionEntry(assetId: 'faction_canxinghui', name: '残星会', moegirlName: '残星会'),
    FactionEntry(assetId: 'faction_huanglong', name: '煌龙', moegirlName: '煌龙（鸣潮）'),
    FactionEntry(assetId: 'faction_jiting', name: '稷庭', moegirlName: '稷庭'),
    FactionEntry(assetId: 'faction_qiqiu', name: '七丘', moegirlName: '七丘'),
    FactionEntry(assetId: 'faction_heihaian', name: '黑海岸', moegirlName: '黑海岸'),
    FactionEntry(assetId: 'faction_laguna', name: '拉古那', moegirlName: '拉古那'),
    FactionEntry(assetId: 'faction_xianxinggongyue', name: '先行公约', moegirlName: '先行公约'),
    FactionEntry(assetId: 'faction_xinlianmeng', name: '新联盟', moegirlName: '新联盟'),
    FactionEntry(assetId: 'faction_liushang', name: '流殇', moegirlName: '流殇'),
    FactionEntry(assetId: 'faction_guiyin', name: '归隐', moegirlName: '归隐'),
    FactionEntry(assetId: 'faction_heimenli', name: '黑门里', moegirlName: '黑门里'),
  ];

  /// 缓存键
  static const String _cacheKeyPrefix = 'faction_detail_moegirl_';

  /// 获取势力列表（返回本地预定义列表）
  Future<FactionListResult> getList() async {
    return FactionListResult(
      entries: _localFactions,
      lastUpdate: DateTime.now(),
    );
  }

  /// 获取势力详情（从萌娘百科获取，带缓存）
  Future<FactionDetail?> getDetail(String factionName) async {
    // 找到对应的势力条目
    final faction = _localFactions.where((f) => f.name == factionName).firstOrNull;
    final moegirlName = faction?.moegirlName ?? factionName;

    // 先尝试从缓存读取
    final cached = _getCached(factionName);
    if (cached != null) {
      // 检查缓存是否过期（7天）
      final age = DateTime.now().difference(cached.lastUpdate ?? DateTime.now());
      if (age.inDays < 7) {
        return cached;
      }
    }

    // 从萌娘百科获取
    try {
      // 直接使用预设的萌娘百科词条名
      String targetPage = moegirlName;

      // 如果不是精确词条，先搜索
      if (!moegirlName.contains('（鸣潮）')) {
        final searchResults = await _client.searchPages('鸣潮 $moegirlName');
        for (final result in searchResults) {
          if (result.contains(moegirlName) && result.contains('鸣潮')) {
            targetPage = result;
            break;
          }
        }
      }

      // 获取摘要
      final summary = await _client.getPageExtract(targetPage);

      // 获取完整内容（HTML）
      final fullContent = await _client.getPageContent(targetPage);

      if (summary == null && fullContent == null) {
        return cached; // 获取失败，返回旧缓存
      }

      final detail = FactionDetail.fromMoegirl(
        name: factionName,
        summary: summary,
        fullContent: fullContent,
      );

      // 保存到缓存
      await _saveCache(factionName, detail);

      return detail;
    } catch (e) {
      // 失败时返回缓存（即使过期）
      return cached;
    }
  }

  /// 从缓存读取
  FactionDetail? _getCached(String factionName) {
    final key = '$_cacheKeyPrefix$factionName';
    final jsonStr = AppStorage.getSetting<String>(key, '');
    if (jsonStr.isEmpty) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return FactionDetail.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 保存到缓存
  Future<void> _saveCache(String factionName, FactionDetail detail) async {
    final key = '$_cacheKeyPrefix$factionName';
    await AppStorage.setSetting(key, jsonEncode(detail.toJson()));
  }

  /// 清空所有缓存
  Future<void> clearCache() async {
    for (final faction in _localFactions) {
      final key = '$_cacheKeyPrefix${faction.name}';
      await AppStorage.setSetting(key, ''); // 设置为空字符串以清除
    }
  }

  /// 检查更新（空实现，兼容wiki_sync.dart）
  Future<bool> checkForUpdates() async {
    // 萌娘百科数据按需加载，无需预先检查更新
    return false;
  }

  void dispose() {
    _client.dispose();
  }
}

/// Provider
final factionServiceProvider = Provider<FactionService>((ref) => FactionService.instance);

final factionListProvider = FutureProvider<FactionListResult>((ref) async {
  final service = ref.watch(factionServiceProvider);
  return service.getList();
});

final factionDetailProvider = FutureProvider.family<FactionDetail?, String>((ref, factionName) async {
  final service = ref.watch(factionServiceProvider);
  return service.getDetail(factionName);
});
