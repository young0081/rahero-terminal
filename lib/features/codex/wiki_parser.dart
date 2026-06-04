import 'wiki_categories.dart';
import 'wiki_models.dart';

/// 把库街区 wiki 原始 JSON 解析为领域模型。
///
/// 只挑选稳定的少数字段，对缺字段 / 类型异常容错：单条解析失败只跳过该条，
/// 不影响整体（库街区 JSON 含大量编辑器占位字段，结构易变）。
class WikiParser {
  WikiParser._();

  /// 解析 getPage 返回的 `data` → 条目列表。
  /// 路径：data.results.records[] → 每条取 name / content.contentUrl /
  /// content.star / content.linkConfig.entryId。
  static List<WikiEntry> parseList(
      Map<String, dynamic>? data, WikiCategory category) {
    final out = <WikiEntry>[];
    final results = _map(data?['results']);
    final records = results?['records'];
    if (records is! List) return out;

    for (final rec in records) {
      try {
        final r = _map(rec);
        if (r == null) continue;
        final content = _map(r['content']) ?? const {};
        final name = (r['name'] ?? content['title'] ?? '').toString();
        final figureUrl = (content['contentUrl'] ?? '').toString();
        if (name.isEmpty) continue; // 无名条目跳过
        out.add(WikiEntry(
          id: (r['id'] ?? '').toString(),
          name: name,
          star: _parseStar(content['star']),
          figureUrl: figureUrl,
          entryId: extractEntryId(content),
          category: category,
        ));
      } catch (_) {/* 单条失败跳过 */}
    }
    return out;
  }

  /// 解析 getEntryDetail 返回的 `data` → 词条详情。
  /// 组件形态：
  /// - role-component：角色 role.{info[].text, figures[].url}
  /// - basic/text-component：title + HTML content
  /// - tabs-component：title + tabs[].{title, content}（真实表格在此，
  ///   如角色统计 / 技能介绍 / 突破材料 / 角色故事）
  static WikiEntryDetail parseDetail(Map<String, dynamic>? data) {
    final content = _map(data?['content']) ?? const {};
    final name = (content['title'] ?? data?['name'] ?? '').toString();
    final infoLines = <String>[];
    final imageUrls = <String>[];
    final sections = <WikiSection>[];
    final voiceTabs = <WikiVoiceTab>[];

    final modules = content['modules'];
    if (modules is List) {
      for (final m in modules) {
        final moduleTitle = (_map(m)?['title'] ?? '').toString().trim();
        final comps = _map(m)?['components'];
        if (comps is! List) continue;
        for (final c in comps) {
          final comp = _map(c);
          if (comp == null) continue;

          // 形态 0：音频组件（角色语音）。mediaTabs[].mediaList[]，
          // 每条含 playUrl(.wav) / audioTitle / content(台词)。
          if (comp['type'] == 'audio-component') {
            _parseAudio(comp, voiceTabs);
            continue;
          }

          // 形态 A：角色 role 组件
          final role = _map(comp['role']);
          if (role != null) {
            final info = role['info'];
            if (info is List) {
              for (final line in info) {
                final t = _map(line)?['text']?.toString();
                if (t != null && t.trim().isNotEmpty) infoLines.add(t.trim());
              }
            }
            final figures = role['figures'];
            if (figures is List) {
              for (final fig in figures) {
                final u = _map(fig)?['url']?.toString();
                if (u != null && u.isNotEmpty) imageUrls.add(u);
              }
            }
            continue;
          }

          // 形态 B：非角色组件 → 标题 + 有序内容块（段落 / 表格）。正文可能在：
          //  - content：basic-component / text-component（HTML 字符串）
          //  - tabs[].content：tabs-component（角色统计/技能/突破材料/角色故事等，
          //    真实表格在这里；表格须保留行列结构，拍平成文本会"丢失表格"）
          // 标题为编辑器默认名（以"组件"结尾，如"纯文本组件"）或为空时，
          // 回退用模块名（如"角色攻略"），避免突兀的内部类型名露出。
          var title = (comp['title'] ?? '').toString().trim();
          if (title.isEmpty || title.endsWith('组件')) {
            title = moduleTitle;
          }
          final blocks = <WikiBlock>[];

          blocks.addAll(_parseRichContent(comp['content']));

          final tabs = comp['tabs'];
          if (tabs is List) {
            for (final t in tabs) {
              final tab = _map(t);
              if (tab == null) continue;
              final tabTitle = (tab['title'] ?? '').toString().trim();
              final tabBlocks = _parseRichContent(tab['content']);
              if (tabBlocks.isEmpty) continue;
              // 多 tab 时用 tab 标题分隔（如技能 1/2/3、突破等级）。
              if (tabTitle.isNotEmpty) {
                blocks.add(WikiBlock.text('【$tabTitle】'));
              }
              blocks.addAll(tabBlocks);
            }
          }

          if (blocks.isNotEmpty) {
            sections.add(WikiSection(title: title, blocks: blocks));
          }
        }
      }
    }

    // story 仅角色为字符串；武器/声骸为 {} 等非字符串，置空避免渲染 "{}"。
    final rawStory = content['story'];
    final story = rawStory is String ? rawStory : '';

    return WikiEntryDetail(
      name: name,
      infoLines: infoLines,
      story: story,
      imageUrls: imageUrls,
      sections: sections,
      voiceTabs: voiceTabs,
    );
  }

  /// 解析 audio-component → 语音分类列表。
  /// 结构：mediaTabs[].{title, mediaList[].{playUrl, audioTitle, content}}。
  /// 只收有有效 playUrl 的语音；空分类跳过。
  static void _parseAudio(
      Map<String, dynamic> comp, List<WikiVoiceTab> out) {
    final tabs = comp['mediaTabs'];
    if (tabs is! List) return;
    for (final t in tabs) {
      final tab = _map(t);
      if (tab == null) continue;
      final tabTitle = (tab['title'] ?? '').toString().trim();
      final list = tab['mediaList'];
      if (list is! List) continue;
      final voices = <WikiVoice>[];
      for (final v in list) {
        final vm = _map(v);
        if (vm == null) continue;
        final url = (vm['playUrl'] ?? '').toString().trim();
        if (url.isEmpty || !url.startsWith('http')) continue;
        voices.add(WikiVoice(
          title: (vm['audioTitle'] ?? '语音').toString().trim(),
          url: url,
          text: _stripHtml(vm['content']),
        ));
      }
      if (voices.isNotEmpty) {
        out.add(WikiVoiceTab(
            title: tabTitle.isEmpty ? '语音' : tabTitle, voices: voices));
      }
    }
  }

  static int _parseStar(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// 解析详情 entryId。两种链接形态：
  /// - linkType 1：直接给 linkConfig.entryId。
  /// - linkType 2：无 entryId，详情入口在 linkConfig.linkUrl（`.../mc/item/<id>`），
  ///   其末段数字即 entryId（部分声骸属此类，否则会误判"暂无详情"）。
  /// 公开供更新检测的指纹（_listSignature）复用，确保两处取 entryId 规则一致。
  static String extractEntryId(Map<String, dynamic> content) {
    final link = _map(content['linkConfig']);
    final id = link?['entryId'];
    if (id != null && id.toString().isNotEmpty) return id.toString();
    final url =
        (link?['linkUrl'] ?? content['linkUrl'] ?? '').toString();
    final m = RegExp(r'/item/(\d+)').firstMatch(url);
    return m != null ? m.group(1)! : '';
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }

  /// 把一段富文本 HTML 切成有序内容块：表格块（保留行列）与文本段落块。
  /// 表格 [<table>…</table>] 单独解析为行列，其余文本走 [_stripHtml]。
  /// 非字符串 / 空输入返回空列表。
  static List<WikiBlock> _parseRichContent(dynamic html) {
    if (html is! String || html.isEmpty) return const [];
    final blocks = <WikiBlock>[];
    final tableRe =
        RegExp(r'<table[^>]*>[\s\S]*?</table>', caseSensitive: false);
    var last = 0;
    for (final m in tableRe.allMatches(html)) {
      if (m.start > last) {
        _appendTextAndImages(html.substring(last, m.start), blocks);
      }
      final rows = _parseTableRows(m.group(0)!);
      if (rows.isNotEmpty) blocks.add(WikiBlock.table(rows));
      last = m.end;
    }
    if (last < html.length) {
      _appendTextAndImages(html.substring(last), blocks);
    }
    return _mergeAdjacentTables(blocks);
  }

  /// 合并同一段内容里相邻且列数相同的表格。
  /// 库街区常把一组数据拆成多个 <table>（如突破材料：一个带边框的"等级要求+突破素材"
  /// 标签表 + 一个 border-style:hidden 的素材网格表），分开渲染会让素材"跑到表格外"。
  /// 列数相同才合并，避免把宽度不同的独立表格错误拼接。
  static List<WikiBlock> _mergeAdjacentTables(List<WikiBlock> blocks) {
    if (blocks.length < 2) return blocks;
    final out = <WikiBlock>[];
    for (final b in blocks) {
      if (b.isTable &&
          out.isNotEmpty &&
          out.last.isTable &&
          _colCount(out.last.rows) == _colCount(b.rows)) {
        out[out.length - 1] =
            WikiBlock.table([...out.last.rows, ...b.rows]);
      } else {
        out.add(b);
      }
    }
    return out;
  }

  static int _colCount(List<List<WikiCell>> rows) =>
      rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);

  /// 把非表格 HTML 段按 <img> 切成「文本块 + 图片块」的有序序列。
  /// 图片不再被去标签丢弃，而是提取 src 作为独立图片块（运行时下载缓存）。
  static void _appendTextAndImages(String html, List<WikiBlock> out) {
    final imgRe = RegExp(r'<img[^>]*>', caseSensitive: false);
    var last = 0;
    for (final m in imgRe.allMatches(html)) {
      if (m.start > last) {
        final t = _stripHtml(html.substring(last, m.start));
        if (t.isNotEmpty) out.add(WikiBlock.text(t));
      }
      final src = _imgSrc(m.group(0)!);
      if (src.isNotEmpty) out.add(WikiBlock.image(src));
      last = m.end;
    }
    if (last < html.length) {
      final t = _stripHtml(html.substring(last));
      if (t.isNotEmpty) out.add(WikiBlock.text(t));
    }
  }

  /// 从一段 HTML 中提取第一个 src 属性值。无则空串。
  /// 带前导边界（行首/空白/引号），避免命中 data-src 等以 src 结尾的属性名
  /// 而抓到懒加载占位图地址。
  static String _imgSrc(String html) {
    final m = RegExp(r'''(?:^|[\s"'])src\s*=\s*["']([^"']+)["']''',
            caseSensitive: false)
        .firstMatch(html);
    return m != null ? m.group(1)!.trim() : '';
  }

  /// 提取第一个 <a> 的 href（仅 http/https 外链）。无则空串。
  static String _aHref(String html) {
    final m = RegExp(r'''<a[^>]*?\shref\s*=\s*["']([^"']+)["']''',
            caseSensitive: false)
        .firstMatch(html);
    final url = m != null ? m.group(1)!.trim() : '';
    return url.startsWith('http') ? url : '';
  }

  /// 解析单个 [<table>] HTML → 行列二维数组。每个单元格取文本 + 第一个内嵌图标 URL，
  /// colspan="N" 的单元格在其后补 N-1 个空单元格以对齐列。
  static List<List<WikiCell>> _parseTableRows(String tableHtml) {
    final rows = <List<WikiCell>>[];
    final trRe = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
    final cellRe = RegExp(r'<(?:td|th)([^>]*)>([\s\S]*?)</(?:td|th)>',
        caseSensitive: false);
    final colspanRe =
        RegExp(r'colspan\s*=\s*"?(\d+)', caseSensitive: false);
    for (final tr in trRe.allMatches(tableHtml)) {
      final cells = <WikiCell>[];
      for (final cell in cellRe.allMatches(tr.group(1) ?? '')) {
        final inner = cell.group(2) ?? '';
        // 先切出第一个 <img> 标签再取 src，避免误采 <source>/<video> 等非图标签。
        final imgTag =
            RegExp(r'<img[^>]*>', caseSensitive: false).firstMatch(inner);
        final cellImg = imgTag != null ? _imgSrc(imgTag.group(0)!) : '';
        cells.add(WikiCell(_stripInline(inner), cellImg, _aHref(inner)));
        final cs = colspanRe.firstMatch(cell.group(1) ?? '');
        final span = cs != null ? (int.tryParse(cs.group(1)!) ?? 1) : 1;
        for (var k = 1; k < span; k++) {
          cells.add(const WikiCell(''));
        }
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  /// 单元格内联去标签：去所有标签、解实体、把所有空白压成单空格（单行）。
  static String _stripInline(dynamic html) {
    if (html is! String || html.isEmpty) return '';
    var s = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = _decodeEntities(s);
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 把库街区富文本 HTML 去标签为纯文本：块级标签转换行，单元格转空格，
  /// 解常见实体，压缩空白。非字符串输入返回空串。
  static String _stripHtml(dynamic html) {
    if (html is! String || html.isEmpty) return '';
    var s = html;
    // 块级/行结束标签转换行，单元格/列表项转空格，便于阅读。
    s = s.replaceAll(RegExp(r'</(tr|p|div|br|li|h[1-6])\s*>',
        caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</(td|th)\s*>', caseSensitive: false), ' ');
    // 去掉其余所有标签。
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = _decodeEntities(s);
    // 逐行压空白，去空行。
    final lines = s
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.join('\n');
  }

  /// 解码 HTML 实体：常见命名实体 + 数字实体（&#123; / &#x1F;）兜底。
  static String _decodeEntities(String input) {
    var s = input;
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&#39;': "'",
      '&times;': '×',
      '&divide;': '÷',
      '&hellip;': '…',
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&lsquo;': '‘',
      '&rsquo;': '’',
      '&mdash;': '—',
      '&ndash;': '–',
      '&middot;': '·',
      '&bull;': '•',
      '&deg;': '°',
      '&plusmn;': '±',
      '&copy;': '©',
      '&reg;': '®',
    };
    entities.forEach((k, v) => s = s.replaceAll(k, v));
    // 数字实体兜底：&#123; 与 &#x1F; 解码为对应字符（覆盖未列名的实体）。
    s = s.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
      final isHex = m.group(1) == 'x';
      final code = int.tryParse(m.group(2)!, radix: isHex ? 16 : 10);
      if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
      try {
        return String.fromCharCode(code);
      } catch (_) {
        return m.group(0)!;
      }
    });
    return s;
  }
}
