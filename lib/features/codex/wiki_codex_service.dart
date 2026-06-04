import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/storage/app_storage.dart';
import '../provisioning/asset_service.dart';
import 'kuro_wiki_client.dart';
import 'wiki_categories.dart';
import 'wiki_models.dart';
import 'wiki_parser.dart';

/// 某分类列表的拉取结果，含是否来自缓存的标记。
class CodexListResult {
  final WikiCategory category;
  final List<WikiEntry> entries;
  final bool fromCache;
  final bool stale; // 来自缓存且本次刷新失败 → 可能非最新
  final String? error;

  const CodexListResult({
    required this.category,
    required this.entries,
    this.fromCache = false,
    this.stale = false,
    this.error,
  });
}

/// 更新检测结果：本次检查新增/更新条目数与是否联网成功。
class WikiSyncResult {
  final int newCount; // 新增条目数
  final int updatedCount; // 被官方更新的条目数
  final bool ok; // 至少一类联网成功
  final String? error;

  const WikiSyncResult({
    this.newCount = 0,
    this.updatedCount = 0,
    this.ok = true,
    this.error,
  });

  bool get hasChanges => newCount > 0 || updatedCount > 0;
}

/// 图鉴内容协调器：列表拉取 + 缓存，详情 / 图片惰性获取。
///
/// 列表是进入资料库的最小必要数据（轻量 JSON），优先且可并发拉取并缓存；
/// 图片与详情在进入 / 点开条目时按需获取，经 asset-provisioning 下载缓存。
class WikiCodexService {
  WikiCodexService._();
  static final WikiCodexService instance = WikiCodexService._();

  final KuroWikiClient _client = KuroWikiClient();
  final AssetService _assets = AssetService.instance;

  // getTree 结果缓存在内存（一次会话内复用），用于动态解析分类 id。
  Map<String, dynamic>? _tree;

  Future<Map<String, dynamic>?> _ensureTree() async {
    if (_tree != null) return _tree;
    final res = await _client.getTree();
    if (res.ok) _tree = res.data;
    return _tree;
  }

  String _listKey(WikiCategory c) => 'list_${c.name}';

  /// 拉取某分类列表：优先用缓存（版本未变），否则联网刷新。
  /// 联网失败但有缓存 → 返回缓存并标记 stale；无缓存 → 返回 error。
  Future<CodexListResult> fetchList(WikiCategory category,
      {bool forceRefresh = false}) async {
    final key = _listKey(category);
    final cachedJson = AppStorage.getCodexJson(key);

    if (!forceRefresh && cachedJson != null) {
      final cached = _decodeList(cachedJson, category);
      if (cached != null) {
        return CodexListResult(
            category: category, entries: cached, fromCache: true);
      }
    }

    final tree = await _ensureTree();
    final catalogueId = resolveCategoryId(tree, category);
    final res = await _client.getPage(catalogueId, page: 1, limit: 200);

    if (!res.ok) {
      // 联网失败：有缓存就降级用缓存（标记 stale），否则报错。
      if (cachedJson != null) {
        final cached = _decodeList(cachedJson, category);
        if (cached != null) {
          return CodexListResult(
              category: category,
              entries: cached,
              fromCache: true,
              stale: true,
              error: res.error);
        }
      }
      return CodexListResult(
          category: category, entries: const [], error: res.error);
    }

    final entries = WikiParser.parseList(res.data, category);
    // 写缓存（仅条目精简模型，不存原始庞杂 JSON）。
    await AppStorage.setCodexJson(
        key, jsonEncode(entries.map((e) => e.toJson()).toList()));
    return CodexListResult(category: category, entries: entries);
  }

  /// 并发拉取首批三类（共鸣者 / 武器 / 声骸）。
  Future<List<CodexListResult>> fetchAllLists({bool forceRefresh = false}) {
    return Future.wait(WikiCategory.values
        .map((c) => fetchList(c, forceRefresh: forceRefresh)));
  }

  List<WikiEntry>? _decodeList(String json, WikiCategory category) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => WikiEntry.fromCache(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 惰性获取条目详情：优先缓存，否则联网拉取并缓存。失败返回 null。
  Future<WikiEntryDetail?> fetchDetail(WikiEntry entry,
      {bool forceRefresh = false}) async {
    if (!entry.hasDetail) return null;
    final key = 'detail_${entry.entryId}';
    final cachedJson = AppStorage.getCodexJson(key);
    if (!forceRefresh && cachedJson != null) {
      try {
        return WikiEntryDetail.fromCache(
            jsonDecode(cachedJson) as Map<String, dynamic>);
      } catch (_) {/* 缓存损坏，重新拉取 */}
    }

    final res = await _client.getEntryDetail(entry.entryId);
    if (!res.ok) {
      // 联网失败：有缓存就用缓存降级。
      if (cachedJson != null) {
        try {
          return WikiEntryDetail.fromCache(
              jsonDecode(cachedJson) as Map<String, dynamic>);
        } catch (_) {/* 落空 */}
      }
      return null;
    }
    final detail = WikiParser.parseDetail(res.data);
    // 仅在解析出实际内容时缓存：全空多半是响应半截 / 畸形 JSON，
    // 缓存空结果会让后续一直返回空白详情。空结果照常返回但不落盘，
    // 下次点开会重新拉取。
    final hasContent = detail.sections.isNotEmpty ||
        detail.infoLines.isNotEmpty ||
        detail.story.isNotEmpty ||
        detail.imageUrls.isNotEmpty ||
        detail.voiceTabs.isNotEmpty;
    if (hasContent) {
      await AppStorage.setCodexJson(key, jsonEncode(detail.toJson()));
    }
    return detail;
  }

  /// 惰性获取详情内的某张图到本地缓存，返回本地路径；失败返回 null。
  Future<String?> ensureDetailImage(WikiEntry entry, String url, int index) {
    if (url.isEmpty) return Future.value(null);
    final ext = _extOf(url);
    return _assets.ensureFileFromUrl(
      url,
      'wiki/${entry.category.name}/${entry.entryId}_$index$ext',
    );
  }

  /// 按 URL 去重下载任意图片（详情内嵌图、表格图标等），返回本地路径；失败返回 null。
  /// 缓存文件名取 URL 的 sha1，相同 URL 只下一次、全图鉴共享（避免重复图标反复下载）。
  Future<String?> ensureImage(String url) {
    if (url.isEmpty) return Future.value(null);
    final ext = _extOf(url);
    final h = sha1.convert(utf8.encode(url)).toString();
    return _assets.ensureFileFromUrl(url, 'wiki/img/$h$ext');
  }

  /// 刷新全部图鉴内容：清空缓存（列表 + 详情）与内存树，重新拉取列表。
  /// 幂等可重入；图片文件保留（按 URL 命中缓存）。
  /// 清 codex 后详情会在再次点开时重新拉取并解析（避免运行期手动刷新读到旧坏数据）。
  Future<List<CodexListResult>> refreshAll() async {
    _tree = null;
    await AppStorage.clearCodex();
    return fetchAllLists(forceRefresh: true);
  }

  /// 检测库街区是否有新内容/被更新的条目，有则增量同步列表缓存并失效相关详情。
  ///
  /// 轻量：每类只拉一次列表（约几十~百KB），用 entryId+updateAt 指纹比对：
  /// - 新 entryId → 新增条目；updateAt 变化 → 该条目被官方更新（删其详情缓存，
  ///   下次点开重拉，连带下载新素材）。
  /// - 首次检查（无历史指纹）只建立基线，不报"新增"，避免升级后误报全量新增。
  /// 联网失败的分类跳过（保留旧缓存），不抛异常。
  Future<WikiSyncResult> checkForUpdates() async {
    var newCount = 0;
    var updatedCount = 0;
    var anyOk = false;
    String? firstError;

    for (final cat in WikiCategory.values) {
      try {
        final tree = await _ensureTree();
        final catId = resolveCategoryId(tree, cat);
        final res = await _client.getPage(catId, page: 1, limit: 200);
        if (!res.ok) {
          firstError ??= res.error;
          continue;
        }
        anyOk = true;

        final curSig = _listSignature(res.data);
        final sigKey = 'sig_${cat.name}';
        final prevRaw = AppStorage.getCodexJson(sigKey);
        final prevSig = _decodeSig(prevRaw);

        // 内容有变才更新缓存（指纹一致直接跳过，省写盘）。
        final sameSig = prevRaw != null &&
            prevSig.length == curSig.length &&
            curSig.entries.every((e) => prevSig[e.key] == e.value);
        if (sameSig) continue;

        // 仅当已建立过基线（prevRaw 非空，即使内容为 "{}"）时才统计新增/更新，
        // 失效被更新条目的详情缓存。用 prevRaw 而非 prevSig 是否为空判断，
        // 以区分"从未检查"与"基线恰好为空"，避免曾空分类的首批真实新增被漏报。
        if (prevRaw != null) {
          for (final e in curSig.entries) {
            final old = prevSig[e.key];
            if (old == null) {
              newCount++;
            } else if (old != e.value) {
              updatedCount++;
              await AppStorage.deleteCodexJson('detail_${e.key}');
            }
          }
        }

        // 更新列表缓存与指纹。
        final entries = WikiParser.parseList(res.data, cat);
        await AppStorage.setCodexJson('list_${cat.name}',
            jsonEncode(entries.map((e) => e.toJson()).toList()));
        await AppStorage.setCodexJson(sigKey, jsonEncode(curSig));
      } catch (e) {
        firstError ??= '$e';
      }
    }

    return WikiSyncResult(
      newCount: newCount,
      updatedCount: updatedCount,
      ok: anyOk,
      error: anyOk ? null : firstError,
    );
  }

  /// 从 getPage 的 data 提取 {entryId: 指纹} 映射（与 parseList 同源取 entryId）。
  /// 指纹 = updateAt|contentUrl 复合值：updateAt 反映官方更新，contentUrl 兜底
  /// （即便 updateAt 缺失，图片地址变化也能被检出）。
  /// 与 parseList 一致跳过无名条目，避免指纹计数与可见列表漂移。
  Map<String, String> _listSignature(Map<String, dynamic>? data) {
    final out = <String, String>{};
    final results = _mapOf(data?['results']);
    final records = results?['records'];
    if (records is List) {
      for (final r in records) {
        final rec = _mapOf(r);
        final content = _mapOf(rec?['content']);
        if (content == null) continue;
        final name = (rec?['name'] ?? content['title'] ?? '').toString();
        if (name.isEmpty) continue; // 与 parseList 一致：无名条目不计入
        // 与 parseList 同源取 entryId（含 linkType2 的 linkUrl 兜底），
        // 否则那些声骸进不了指纹→更新检测对它们隐形、详情缓存永不失效。
        final eid = WikiParser.extractEntryId(content);
        if (eid.isEmpty) continue;
        final upd = (content['updateAt'] ?? '').toString();
        final curl = (content['contentUrl'] ?? '').toString();
        out[eid] = '$upd|$curl';
      }
    }
    return out;
  }

  Map<String, String> _decodeSig(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        return m.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {/* 损坏视为无基线 */}
    return {};
  }

  Map<String, dynamic>? _mapOf(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }

  /// 从 URL 末段推断扩展名，默认 .png。
  String _extOf(String url) {
    final q = url.indexOf('?');
    final clean = q >= 0 ? url.substring(0, q) : url;
    final dot = clean.lastIndexOf('.');
    final slash = clean.lastIndexOf('/');
    if (dot > slash && dot >= 0 && dot < clean.length - 1) {
      final ext = clean.substring(dot).toLowerCase();
      const ok = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};
      if (ok.contains(ext)) return ext;
    }
    return '.png';
  }
}