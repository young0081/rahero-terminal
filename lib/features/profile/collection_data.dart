import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';

/// 收藏夹 + 使用统计：记录用户看过/收藏的图鉴条目。
///
/// 全部本地存储。收藏项与浏览记录用 'category:entryId' 作 key（稳定唯一）。
class CollectionState {
  final Set<String> favorites; // 收藏的条目 key 集合
  final Set<String> viewed; // 浏览过的条目 key 集合

  const CollectionState({
    this.favorites = const {},
    this.viewed = const {},
  });

  CollectionState copyWith({Set<String>? favorites, Set<String>? viewed}) =>
      CollectionState(
        favorites: favorites ?? this.favorites,
        viewed: viewed ?? this.viewed,
      );

  bool isFavorite(String key) => favorites.contains(key);
  int get favoriteCount => favorites.length;
  int get viewedCount => viewed.length;
}

class CollectionNotifier extends Notifier<CollectionState> {
  static const _favKey = 'collection_favorites';
  static const _viewKey = 'collection_viewed';

  @override
  CollectionState build() {
    return CollectionState(
      favorites: _load(_favKey),
      viewed: _load(_viewKey),
    );
  }

  Set<String> _load(String key) {
    final raw = AppStorage.getSetting<String>(key, '');
    if (raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(String key, Set<String> set) =>
      AppStorage.setSetting(key, jsonEncode(set.toList()));

  /// 切换收藏状态。返回是否是新增收藏（用于触发成就）。
  Future<bool> toggleFavorite(String key) async {
    final next = Set<String>.from(state.favorites);
    final wasAdded = next.add(key);
    if (!wasAdded) next.remove(key);
    state = state.copyWith(favorites: next);
    await _persist(_favKey, next);
    return wasAdded;
  }

  /// 记录浏览（点开详情时调用）。已记录则不重复写盘。返回是否是首次浏览。
  Future<bool> markViewed(String key) async {
    if (state.viewed.contains(key)) return false;
    final next = Set<String>.from(state.viewed)..add(key);
    state = state.copyWith(viewed: next);
    await _persist(_viewKey, next);
    return true;
  }
}

final collectionProvider =
    NotifierProvider<CollectionNotifier, CollectionState>(
        CollectionNotifier.new);

/// 条目 key 构造：分类名 + entryId，稳定唯一。
String collectionKey(String categoryName, String entryId) =>
    '$categoryName:$entryId';
