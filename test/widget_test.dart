import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rahero_terminal/core/theme/app_theme.dart';
import 'package:rahero_terminal/features/feixun/feixun_data.dart';
import 'package:rahero_terminal/features/feixun/message_transport.dart';
import 'package:rahero_terminal/router/app_router.dart';

void main() {
  testWidgets('开机页可构建并显示终端标题', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.build(),
          routerConfig: appRouter,
        ),
      ),
    );

    // 开机页逐行显示，推进首行定时器(420ms)后标题行应出现。
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('拉海洛终端'), findsWidgets);

    // 推进开机序列与保底跳转，排空所有延迟定时器，避免遗留定时器告警。
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 5));
  });

  test('主题构建为银灰冷色调', () {
    final theme = AppTheme.build();
    expect(theme.colorScheme.primary, AppColors.coolAccent);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('势力专属色：星炬绿 / 深空红 / 其余冷调', () {
    expect(AppColors.factionAccent('faction_xingju'), AppColors.xingjuGreen);
    expect(AppColors.factionAccent('faction_shenkong'), AppColors.shenkongRed);
    expect(AppColors.factionAccent('faction_qiqiu'), AppColors.coolAccent);
  });

  test('飞讯消息 JSON 往返：文本与表情都无损', () {
    const text = FeixunMessage(
        id: 'm1', from: 'me', type: 'text', time: '09:00', content: '你好');
    final textBack = FeixunMessage.fromJson(text.toJson());
    expect(textBack.id, 'm1');
    expect(textBack.from, 'me');
    expect(textBack.isMe, true);
    expect(textBack.type, 'text');
    expect(textBack.isEmoji, false);
    expect(textBack.content, '你好');

    const emoji = FeixunMessage(
        id: 'm2',
        from: 'me',
        type: 'emoji',
        time: '09:01',
        content: 'emoji_smile');
    final emojiBack = FeixunMessage.fromJson(emoji.toJson());
    expect(emojiBack.isEmoji, true);
    expect(emojiBack.content, 'emoji_smile');
  });

  test('消息状态：缺 status 字段的旧数据视为已送达', () {
    // 模拟旧持久化数据（无 status 字段）。
    final old = FeixunMessage.fromJson({
      'id': 'm1',
      'from': 'me',
      'type': 'text',
      'time': '09:00',
      'content': '历史消息',
    });
    expect(old.isSent, true);
    expect(old.isSending, false);
    expect(old.isFailed, false);
    expect(old.status, 'sent');
  });

  test('消息状态：status 字段往返无损 + copyWith 改状态', () {
    const sending = FeixunMessage(
        id: 'm2',
        from: 'me',
        type: 'text',
        time: '09:01',
        content: '在发',
        status: 'sending');
    final back = FeixunMessage.fromJson(sending.toJson());
    expect(back.isSending, true);
    expect(back.status, 'sending');

    final failed = back.copyWith(status: 'failed');
    expect(failed.isFailed, true);
    expect(failed.content, '在发'); // 其余字段不变
    expect(failed.id, 'm2');
  });

  test('模拟传输：默认成功；失败率为 1 时抛异常', () async {
    const ok = MockMessageTransport(sendDelay: Duration.zero);
    await ok.send('c1', '{}'); // 不抛 = 成功

    final fail = MockMessageTransport(
      sendDelay: Duration.zero,
      failureRate: 1.0,
      roll: () => 0.0, // 必定 < 失败率 → 失败
    );
    expect(() => fail.send('c1', '{}'),
        throwsA(isA<MessageSendException>()));
  });
}
