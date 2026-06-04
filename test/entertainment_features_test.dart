import 'package:flutter_test/flutter_test.dart';

import 'package:rahero_terminal/features/achievements/achievement_data.dart';
import 'package:rahero_terminal/features/archive/faction_service.dart';
import 'package:rahero_terminal/features/feixun/ugc_script_service.dart';
import 'package:rahero_terminal/features/profile/collection_data.dart';
import 'package:rahero_terminal/features/profile/daily_terminal_event.dart';

void main() {
  test('每日终端事件同一天稳定生成，不同日期可变化', () {
    final a = dailyTerminalEventFor(DateTime(2026, 6, 4, 9));
    final b = dailyTerminalEventFor(DateTime(2026, 6, 4, 23));
    final c = dailyTerminalEventFor(DateTime(2026, 6, 5));

    expect(a.headline, b.headline);
    expect(a.keyword, b.keyword);
    expect(a.dateLabel, '2026.06.04');
    expect(
      [
        a.headline != c.headline,
        a.keyword != c.keyword,
        a.recommendation != c.recommendation,
      ].any((changed) => changed),
      true,
    );
  });

  test('收藏条目快照 JSON 往返', () {
    final item = CollectionItem(
      key: 'resonator:14888',
      category: 'resonator',
      categoryLabel: '共鸣者',
      entryId: '14888',
      name: '达妮娅',
      star: 5,
      figureUrl: 'https://cdn.example/d.png',
      addedAt: DateTime(2026, 6, 4, 18, 30),
    );

    final back = CollectionItem.fromJson(item.toJson());
    expect(back.key, item.key);
    expect(back.categoryLabel, '共鸣者');
    expect(back.name, '达妮娅');
    expect(back.star, 5);
    expect(back.addedAt, item.addedAt);
  });

  test('UGC 分享码可导出并导入，导入保存会生成新 id', () async {
    final service = UGCScriptService();
    final script = UGCScript(
      id: 'old-id',
      title: '测试剧本',
      author: '作者',
      createdAt: DateTime(2026, 6, 4),
      messages: const [
        UGCMessage(speaker: '漂泊者', content: '收到信号。'),
        UGCMessage(speaker: '终端', content: '链路稳定。'),
      ],
    );

    final code = service.exportShareCode(script);
    expect(code.startsWith('RAHERO-UGC-v1:'), true);

    final imported = await service.importFromShareText(code);
    expect(imported, isNotNull);
    expect(imported!.title, script.title);
    expect(imported.messages.length, 2);
    expect(imported.messages.first.content, '收到信号。');
  });

  test('势力档案只包含资源清单支持的条目', () async {
    final result = await FactionService.instance.getList();
    final names = result.entries.map((entry) => entry.name).toList();
    final achievement = kAchievements.firstWhere(
      (item) => item.id == 'faction_explorer',
    );

    expect(names, hasLength(9));
    expect(
      names,
      containsAll([
        '星炬学院',
        '深空联合',
        '残星会',
        '瑝珑',
        '稷庭',
        '七丘',
        '黑海岸',
        '拉古那',
        '先行公约',
      ]),
    );
    expect(names, isNot(contains('新联盟')));
    expect(names, isNot(contains('流殇')));
    expect(names, isNot(contains('归隐')));
    expect(names, isNot(contains('黑门里')));
    expect(achievement.target, names.length);
  });
}
