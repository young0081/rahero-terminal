import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wiki_categories.dart';
import 'wiki_codex_service.dart';
import 'wiki_models.dart';

final _service = WikiCodexService.instance;

/// 某分类的图鉴列表（共鸣者 / 武器 / 声骸）。
/// 优先用缓存，失败时由 service 内部降级；UI 据 stale/error 提示。
final wikiListProvider = FutureProvider.family<CodexListResult, WikiCategory>(
  (ref, category) => _service.fetchList(category),
);

/// 某条目的详情（惰性，点开时拉取）。
final wikiDetailProvider =
    FutureProvider.family<WikiEntryDetail?, WikiEntry>(
  (ref, entry) => _service.fetchDetail(entry),
);

/// 任意图片 URL 的本地缓存路径（按 URL 去重惰性下载）。失败为 null → UI 占位。
/// 立绘、详情内嵌大图、表格内小图标统一走它——key 即 URL，上游换图（URL 变）
/// 自然产生新 key、新缓存路径，自动重下，根治"换图不刷新/清缓存后不重下"。
///
/// autoDispose + 成功才 keepAlive：成功的常驻缓存（滚动不反复解析），失败的
/// 不常驻（卡片重新进入视图时自动重试）。await 后用 ref.mounted 守卫 keepAlive，
/// 避免下载途中卡片滚走、provider 被销毁后调用 keepAlive 抛 UnmountedRefException。
final wikiImageProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, url) async {
  final path = await _service.ensureImage(url);
  if (path != null && ref.mounted) ref.keepAlive();
  return path;
});

/// 手动刷新全部图鉴：清缓存并重新拉取，随后失效相关 provider。
final wikiRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await _service.refreshAll();
    ref.invalidate(wikiListProvider);
    ref.invalidate(wikiDetailProvider);
  };
});
