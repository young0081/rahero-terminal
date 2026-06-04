import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 飞讯单条消息。
class FeixunMessage {
  final String id;
  final String from; // me / peer
  final String type; // text / emoji / image / voice / file
  final String time;
  final String content; // type=text 时为文本；type=emoji 时为表情 id；type=image/voice/file 时为 URL 或路径
  final String status; // sending / sent / failed；缺省 sent（向后兼容旧数据）
  final Map<String, dynamic>? metadata; // 附加元数据（文件名、时长、尺寸等）
  final bool isRead; // 已读状态，默认 false

  const FeixunMessage({
    required this.id,
    required this.from,
    required this.type,
    required this.time,
    required this.content,
    this.status = 'sent',
    this.metadata,
    this.isRead = false,
  });

  bool get isMe => from == 'me';
  bool get isEmoji => type == 'emoji';
  bool get isImage => type == 'image';
  bool get isVoice => type == 'voice';
  bool get isFile => type == 'file';
  bool get isSending => status == 'sending';
  bool get isFailed => status == 'failed';
  bool get isSent => status == 'sent';

  factory FeixunMessage.fromJson(Map<String, dynamic> j) => FeixunMessage(
        id: j['id'] as String? ?? '',
        from: j['from'] as String? ?? 'peer',
        type: j['type'] as String? ?? 'text',
        time: j['time'] as String? ?? '',
        content: j['content'] as String? ?? '',
        // 旧数据无 status 字段 → 视为已送达。
        status: j['status'] as String? ?? 'sent',
        metadata: j['metadata'] as Map<String, dynamic>?,
        isRead: j['isRead'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'type': type,
        'time': time,
        'content': content,
        'status': status,
        if (metadata != null) 'metadata': metadata,
        'isRead': isRead,
      };

  FeixunMessage copyWith({String? status, bool? isRead}) => FeixunMessage(
        id: id,
        from: from,
        type: type,
        time: time,
        content: content,
        status: status ?? this.status,
        metadata: metadata,
        isRead: isRead ?? this.isRead,
      );
}

/// 飞讯联系人（一段会话）。
class FeixunContact {
  final String id;
  final String name;
  final String avatarAssetId;
  final bool pinned;
  final List<FeixunMessage> messages;

  const FeixunContact({
    required this.id,
    required this.name,
    required this.avatarAssetId,
    required this.pinned,
    required this.messages,
  });

  String get lastPreview => messages.isEmpty ? '' : messages.last.content;

  factory FeixunContact.fromJson(Map<String, dynamic> j) => FeixunContact(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        avatarAssetId: j['avatarAssetId'] as String? ?? '',
        pinned: j['pinned'] as bool? ?? false,
        messages: (j['messages'] as List<dynamic>? ?? [])
            .map((e) => FeixunMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 加载飞讯占位剧本。
final feixunContactsProvider =
    FutureProvider<List<FeixunContact>>((ref) async {
  final raw =
      await rootBundle.loadString('assets/scripts/feixun_scripts.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final list = (j['contacts'] as List<dynamic>? ?? [])
      .map((e) => FeixunContact.fromJson(e as Map<String, dynamic>))
      .toList();
  // 置顶排前
  list.sort((a, b) => (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0));
  return list;
});

/// 飞讯表情条目。对应可从库街区下载的贴图(id)，未下载时用 unicode 字形(glyph)兜底。
class FeixunEmoji {
  final String id;
  final String glyph;
  final String name;

  const FeixunEmoji({required this.id, required this.glyph, required this.name});

  factory FeixunEmoji.fromJson(Map<String, dynamic> j) => FeixunEmoji(
        id: j['id'] as String,
        glyph: j['glyph'] as String? ?? '🙂',
        name: j['name'] as String? ?? '',
      );
}

/// 加载表情目录。
final feixunEmojisProvider = FutureProvider<List<FeixunEmoji>>((ref) async {
  final raw =
      await rootBundle.loadString('assets/scripts/feixun_emojis.json');
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return (j['emojis'] as List<dynamic>? ?? [])
      .map((e) => FeixunEmoji.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 按 id 快速查表情（用于渲染表情消息时取 glyph）。
final emojiByIdProvider = FutureProvider<Map<String, FeixunEmoji>>((ref) async {
  final list = await ref.watch(feixunEmojisProvider.future);
  return {for (final e in list) e.id: e};
});
