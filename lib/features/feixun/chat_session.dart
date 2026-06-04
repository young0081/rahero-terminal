import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/storage/app_storage.dart';
import 'feixun_data.dart';
import 'message_transport.dart';

/// 一段会话的消息日志：剧本预置消息 + 用户已发出的消息（持久化）。
///
/// 不依赖 Riverpod 的 family notifier（其 API 随版本变动），作为普通控制器由
/// 聊天页 State 持有；状态变化通过 [onChanged] 通知页面 setState 刷新。
///
/// 网络态：发送经由可替换的 [MessageTransport] 驱动（sending → sent/failed）。
/// 仅 `sent` 终态消息持久化，重启不残留"发送中"幽灵消息。
///
/// 分页加载：初始加载最新 50 条，向上滚动时追加前 50 条。
class ChatLog {
  final FeixunContact contact;
  final List<FeixunMessage> _allMessages; // 全部消息（内部）
  final List<FeixunMessage> messages; // 当前已加载消息（暴露给 UI）
  final MessageTransport transport;

  /// 状态变化回调（页面据此 setState）。
  VoidCallback? onChanged;

  /// 是否正在加载会话历史（模拟弱网下接收消息需要加载）。
  bool isLoadingHistory = true;

  /// 是否还有更多历史消息可加载。
  bool get hasMoreHistory => _allMessages.length > messages.length;

  /// 是否正在加载更多历史。
  bool isLoadingMore = false;

  static const int _pageSize = 50;

  ChatLog._(this.contact, this._allMessages, this.messages, this.transport);

  /// 加载：剧本消息 + 用户历史发送（从持久化恢复，均为已送达终态）。
  /// 初始只加载最新 50 条。
  factory ChatLog.load(FeixunContact contact, {MessageTransport? transport}) {
    final scripted = List<FeixunMessage>.from(contact.messages);
    final sent = _loadSent(contact.id);
    final all = [...scripted, ...sent];
    // 初始加载最新 _pageSize 条
    final initial = all.length > _pageSize
        ? all.sublist(all.length - _pageSize)
        : all;
    return ChatLog._(
      contact,
      all,
      List<FeixunMessage>.from(initial),
      transport ?? const MockMessageTransport(),
    );
  }

  void _notify() => onChanged?.call();

  /// 加载更多历史消息（向前追加 50 条）。
  Future<void> loadMoreHistory() async {
    if (!hasMoreHistory || isLoadingMore) return;
    isLoadingMore = true;
    _notify();

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));

    final currentStart = _allMessages.indexOf(messages.first);
    final loadCount = (currentStart >= _pageSize) ? _pageSize : currentStart;
    if (loadCount > 0) {
      final more =
          _allMessages.sublist(currentStart - loadCount, currentStart);
      messages.insertAll(0, more);
    }

    isLoadingMore = false;
    _notify();
  }

  /// 模拟通过网络同步会话历史（接收加载态）。完成后展示消息。
  Future<void> connect() async {
    isLoadingHistory = true;
    _notify();
    try {
      await transport.awaitIncoming();
    } catch (_) {/* 加载失败也照常展示已有本地消息 */}
    isLoadingHistory = false;
    _notify();
  }

  static List<FeixunMessage> _loadSent(String contactId) {
    final raw = AppStorage.getSentMessages(contactId);
    final out = <FeixunMessage>[];
    for (final s in raw) {
      try {
        final m =
            FeixunMessage.fromJson(jsonDecode(s) as Map<String, dynamic>);
        // 持久化的均视为已送达终态：旧数据或残留的非终态一律落定为 sent，
        // 杜绝重启后出现"永久发送中"幽灵消息。
        if (!m.isSent) {
          // 正常不应发生（只持久化 sent）；记录以便发现数据异常。
          debugPrint(
              '飞讯：加载到非 sent 持久化消息 (id=${m.id}, status=${m.status})，已落定为 sent');
        }
        out.add(m.isSent ? m : m.copyWith(status: 'sent'));
      } catch (_) {/* 跳过损坏条目 */}
    }
    return out;
  }

  static String _now() {
    final d = DateTime.now();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // 单调递增计数，保证同一微秒内连发也不会撞 id。
  static int _seq = 0;
  static String _newId() {
    _seq++;
    return 'me_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  int _indexOf(String id) => messages.indexWhere((m) => m.id == id);

  void _replace(String id, FeixunMessage updated) {
    final i = _indexOf(id);
    if (i >= 0) {
      messages[i] = updated;
      _notify();
    }
  }

  /// 经传输发送，驱动 sending → sent/failed，仅成功时持久化。
  Future<void> _dispatch(FeixunMessage msg) async {
    messages.add(msg); // sending 态先入列表，显示加载指示
    _allMessages.add(msg); // 同步更新全量列表
    _notify();
    try {
      await transport.send(contact.id, jsonEncode(msg.toJson()));
      final sent = msg.copyWith(status: 'sent');
      _replace(msg.id, sent);
      await AppStorage.appendSentMessage(
          contact.id, jsonEncode(sent.toJson()));
    } catch (_) {
      _replace(msg.id, msg.copyWith(status: 'failed'));
    }
  }

  /// 发送文本（空文本忽略）。
  Future<void> sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _dispatch(FeixunMessage(
      id: _newId(),
      from: 'me',
      type: 'text',
      time: _now(),
      content: t,
      status: 'sending',
    ));
  }

  /// 发送表情（content 存表情 id）。
  Future<void> sendEmoji(String emojiId) async {
    await _dispatch(FeixunMessage(
      id: _newId(),
      from: 'me',
      type: 'emoji',
      time: _now(),
      content: emojiId,
      status: 'sending',
    ));
  }

  /// 重试一条失败的消息：重置为 sending 并重新经传输发送。
  Future<void> retry(String messageId) async {
    final i = _indexOf(messageId);
    if (i < 0) return;
    final failed = messages[i];
    if (!failed.isFailed) return;
    // 重置为 sending：发送给传输的消息体状态须与 UI 一致。
    final sending = failed.copyWith(status: 'sending');
    messages[i] = sending;
    _notify();
    try {
      await transport.send(contact.id, jsonEncode(sending.toJson()));
      final sent = sending.copyWith(status: 'sent');
      _replace(messageId, sent);
      await AppStorage.appendSentMessage(
          contact.id, jsonEncode(sent.toJson()));
    } catch (_) {
      _replace(messageId, sending.copyWith(status: 'failed'));
    }
  }

  /// 清空用户发出的消息（仅清自己发的，剧本消息保留）。
  Future<void> clearMine() async {
    await AppStorage.clearSentMessages(contact.id);
    messages
      ..clear()
      ..addAll(contact.messages);
    // 清空后不应再残留"接收中"打字指示。
    isLoadingHistory = false;
    _notify();
  }
}
