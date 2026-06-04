import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';

/// 收藏条目的展示快照。收藏时保存一份轻量元数据，个人页无需重新联网
/// 拉取图鉴列表也能展示展柜。
class CollectionItem {
  final String key;
  final String category;
  final String categoryLabel;
  final String entryId;
  final String name;
  final int star;
  final String figureUrl;
  final DateTime addedAt;

  const CollectionItem({
    required this.key,
    required this.category,
    required this.categoryLabel,
    required this.entryId,
    required this.name,
    required this.star,
    required this.figureUrl,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'category': category,
    'categoryLabel': categoryLabel,
    'entryId': entryId,
    'name': name,
    'star': star,
    'figureUrl': figureUrl,
    'addedAt': addedAt.toIso8601String(),
  };

  factory CollectionItem.fromJson(Map<String, dynamic> j) {
    DateTime parseAddedAt() {
      final raw = (j['addedAt'] ?? '').toString();
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return CollectionItem(
      key: (j['key'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      categoryLabel: (j['categoryLabel'] ?? '').toString(),
      entryId: (j['entryId'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      star: j['star'] is int ? j['star'] as int : 0,
      figureUrl: (j['figureUrl'] ?? '').toString(),
      addedAt: parseAddedAt(),
    );
  }
}

/// 收藏夹 + 使用统计：记录用户看过/收藏的图鉴条目。
///
/// 全部本地存储。收藏项与浏览记录用 'category:entryId' 作 key（稳定唯一）。
class CollectionState {
  final Set<String> favorites; // 收藏的条目 key 集合
  final Set<String> viewed; // 浏览过的条目 key 集合
  final Map<String, CollectionItem> favoriteItems; // 收藏条目的展示快照

  const CollectionState({
    this.favorites = const {},
    this.viewed = const {},
    this.favoriteItems = const {},
  });

  CollectionState copyWith({
    Set<String>? favorites,
    Set<String>? viewed,
    Map<String, CollectionItem>? favoriteItems,
  }) => CollectionState(
    favorites: favorites ?? this.favorites,
    viewed: viewed ?? this.viewed,
    favoriteItems: favoriteItems ?? this.favoriteItems,
  );

  bool isFavorite(String key) => favorites.contains(key);
  int get favoriteCount => favorites.length;
  int get viewedCount => viewed.length;

  List<CollectionItem> get showcaseItems {
    final items = favoriteItems.values.toList();
    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }
}

class CollectionNotifier extends Notifier<CollectionState> {
  static const _favKey = 'collection_favorites';
  static const _viewKey = 'collection_viewed';
  static const _favItemsKey = 'collection_favorite_items';

  @override
  CollectionState build() {
    final favorites = _loadSet(_favKey);
    return CollectionState(
      favorites: favorites,
      viewed: _loadSet(_viewKey),
      favoriteItems: _loadItems(favorites),
    );
  }

  Set<String> _loadSet(String key) {
    final raw = AppStorage.getSetting<String>(key, '');
    if (raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Map<String, CollectionItem> _loadItems(Set<String> favorites) {
    final raw = AppStorage.getSetting<String>(_favItemsKey, '');
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      final items = <String, CollectionItem>{};
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          final parsed = CollectionItem.fromJson(item);
          if (parsed.key.isNotEmpty && favorites.contains(parsed.key)) {
            items[parsed.key] = parsed;
          }
        }
      }
      return items;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persistSet(String key, Set<String> set) =>
      AppStorage.setSetting(key, jsonEncode(set.toList()));

  Future<void> _persistItems(Map<String, CollectionItem> items) =>
      AppStorage.setSetting(
        _favItemsKey,
        jsonEncode(items.values.map((e) => e.toJson()).toList()),
      );

  /// 切换收藏状态。返回是否是新增收藏（用于触发成就）。
  Future<bool> toggleFavorite(String key, {CollectionItem? item}) async {
    final next = Set<String>.from(state.favorites);
    final nextItems = Map<String, CollectionItem>.from(state.favoriteItems);
    final wasAdded = next.add(key);
    if (wasAdded) {
      if (item != null) nextItems[key] = item;
    } else {
      next.remove(key);
      nextItems.remove(key);
    }
    state = state.copyWith(favorites: next, favoriteItems: nextItems);
    await _persistSet(_favKey, next);
    await _persistItems(nextItems);
    return wasAdded;
  }

  /// 记录浏览（点开详情时调用）。已记录则不重复写盘。返回是否是首次浏览。
  Future<bool> markViewed(String key) async {
    if (state.viewed.contains(key)) return false;
    final next = Set<String>.from(state.viewed)..add(key);
    state = state.copyWith(viewed: next);
    await _persistSet(_viewKey, next);
    return true;
  }
}

final collectionProvider =
    NotifierProvider<CollectionNotifier, CollectionState>(
      CollectionNotifier.new,
    );

/// 条目 key 构造：分类名 + entryId，稳定唯一。
String collectionKey(String categoryName, String entryId) =>
    '$categoryName:$entryId';
