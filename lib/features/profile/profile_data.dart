import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_storage.dart';

/// 用户个人信息（本地名片）。所有字段可空/可选，纯本地存储。
class UserProfile {
  final String nickname; // 昵称
  final String signature; // 个性签名
  final String uid; // 游戏 UID（显示用，不对接联网功能）
  final String favoriteRole; // 常用 / 喜爱角色
  final String region; // 所属势力 / 区域

  const UserProfile({
    this.nickname = '',
    this.signature = '',
    this.uid = '',
    this.favoriteRole = '',
    this.region = '',
  });

  UserProfile copyWith({
    String? nickname,
    String? signature,
    String? uid,
    String? favoriteRole,
    String? region,
  }) =>
      UserProfile(
        nickname: nickname ?? this.nickname,
        signature: signature ?? this.signature,
        uid: uid ?? this.uid,
        favoriteRole: favoriteRole ?? this.favoriteRole,
        region: region ?? this.region,
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'signature': signature,
        'uid': uid,
        'favoriteRole': favoriteRole,
        'region': region,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        nickname: (j['nickname'] ?? '').toString(),
        signature: (j['signature'] ?? '').toString(),
        uid: (j['uid'] ?? '').toString(),
        favoriteRole: (j['favoriteRole'] ?? '').toString(),
        region: (j['region'] ?? '').toString(),
      );

  /// 是否为空白名片（用于 UI 提示"点击完善资料"）。
  bool get isEmpty =>
      nickname.isEmpty &&
      signature.isEmpty &&
      uid.isEmpty &&
      favoriteRole.isEmpty &&
      region.isEmpty;
}

/// 个人信息状态管理：从本地加载、修改后持久化。
class ProfileNotifier extends Notifier<UserProfile> {
  static const _key = 'user_profile';

  @override
  UserProfile build() {
    final raw = AppStorage.getSetting<String>(_key, '');
    if (raw.isEmpty) return const UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  /// 保存整份资料。
  Future<void> save(UserProfile profile) async {
    state = profile;
    await AppStorage.setSetting(_key, jsonEncode(profile.toJson()));
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
