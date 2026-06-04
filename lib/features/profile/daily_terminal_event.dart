import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 每日终端事件：按本地日期稳定生成，用户当天反复打开看到同一份简报。
class DailyTerminalEvent {
  final DateTime date;
  final String headline;
  final String brief;
  final String keyword;
  final String recommendation;
  final String sign;
  final String signal;

  const DailyTerminalEvent({
    required this.date,
    required this.headline,
    required this.brief,
    required this.keyword,
    required this.recommendation,
    required this.sign,
    required this.signal,
  });

  String get dateLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }
}

final dailyTerminalEventProvider = Provider<DailyTerminalEvent>((ref) {
  final now = DateTime.now();
  return dailyTerminalEventFor(now);
});

DailyTerminalEvent dailyTerminalEventFor(DateTime rawDate) {
  final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
  final seed = date.year * 10000 + date.month * 100 + date.day;
  final headline = _pick(_headlines, seed, 3);
  final brief = _pick(_briefs, seed, 7);
  final keyword = _pick(_keywords, seed, 11);
  final recommendation = _pick(_recommendations, seed, 17);
  final sign = _pick(_signs, seed, 23);
  final signal = _pick(_signals, seed, 29);
  return DailyTerminalEvent(
    date: date,
    headline: headline,
    brief: brief,
    keyword: keyword,
    recommendation: recommendation,
    sign: sign,
    signal: signal,
  );
}

String _pick(List<String> values, int seed, int salt) {
  final index = (seed * 1103515245 + salt * 12345).abs() % values.length;
  return values[index];
}

const _headlines = [
  '终端链路状态良好',
  '星炬频道完成例行校准',
  '深空监听阵列捕获轻微信号',
  '库街区资料索引等待复核',
  '今日档案柜已解锁新的阅读序列',
  '飞讯缓存完成静默整理',
  '终端外观模块处于稳定态',
  '共鸣数据流出现短暂高峰',
];

const _briefs = [
  '适合整理收藏、补完图鉴，并给自己的终端名片换一句签名。',
  '建议先查看一个角色条目，再回到个人页整理今日展柜。',
  '今天的信号偏向轻松交流，适合创作一段短飞讯剧本。',
  '终端建议从势力档案开始巡查，可能会发现被忽略的背景线索。',
  '适合清理缓存、刷新图鉴，然后收藏一个顺眼的条目。',
  '今日适合慢速浏览资料，别急着一次性把所有内容看完。',
  '如果不知道做什么，就从最近喜欢的角色开始整理收藏。',
  '终端建议为自己的档案补齐昵称、所属势力与常用角色。',
];

const _keywords = ['回响', '星炬', '深空', '档案', '短讯', '银灰', '共鸣', '巡检', '收藏', '剧本'];

const _recommendations = [
  '收藏一个共鸣者条目',
  '给 UGC 剧本写三句对白',
  '查看一份势力档案',
  '切换一次终端主题',
  '补全个人终端档案',
  '刷新图鉴并看一个详情页',
  '把喜欢的武器加入展柜',
  '回看今天的成就进度',
];

const _signs = [
  '今日适配：冷静检索',
  '今日适配：灵感记录',
  '今日适配：资料补完',
  '今日适配：轻量互动',
  '今日适配：收藏整理',
  '今日适配：终端美化',
];

const _signals = [
  'SIGNAL 0xA7',
  'SIGNAL 0xC1',
  'SIGNAL 0xE4',
  'SIGNAL 0x39',
  'SIGNAL 0x5D',
  'SIGNAL 0x88',
];
