import 'wiki_categories.dart';

/// 图鉴列表条目（来自 getPage 的 records[]）。
class WikiEntry {
  final String id; // 目录项 id（records[].id）
  final String name;
  final int star; // 星级，解析失败为 0
  final String figureUrl; // 立绘 / 缩略图 URL
  final String entryId; // 详情 entryId（content.linkConfig.entryId）
  final WikiCategory category;

  const WikiEntry({
    required this.id,
    required this.name,
    required this.star,
    required this.figureUrl,
    required this.entryId,
    required this.category,
  });

  bool get hasDetail => entryId.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is WikiEntry &&
      other.id == id &&
      other.category == category &&
      other.entryId == entryId;

  @override
  int get hashCode => Object.hash(id, category, entryId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'star': star,
        'figureUrl': figureUrl,
        'entryId': entryId,
        'category': category.name,
      };

  factory WikiEntry.fromCache(Map<String, dynamic> j) => WikiEntry(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        star: j['star'] is int ? j['star'] as int : 0,
        figureUrl: (j['figureUrl'] ?? '').toString(),
        entryId: (j['entryId'] ?? '').toString(),
        category: WikiCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => WikiCategory.resonator,
        ),
      );
}

/// 表格单元格：文本 + 可选图标 URL（突破材料/技能图标）+ 可选链接 URL（<a href>）。
class WikiCell {
  final String text;
  final String imageUrl; // 单元格内嵌图标 URL，无则空串
  final String linkUrl; // 单元格内 <a href> 链接（如角色攻略专题页），无则空串

  const WikiCell(this.text, [this.imageUrl = '', this.linkUrl = '']);

  bool get isLink => linkUrl.isNotEmpty;

  Map<String, dynamic> toJson() => {
        't': text,
        if (imageUrl.isNotEmpty) 'i': imageUrl,
        if (linkUrl.isNotEmpty) 'l': linkUrl,
      };

  /// 兼容旧缓存：旧版单元格是纯字符串，新版是 {t,i,l} 对象。
  factory WikiCell.fromCache(dynamic j) {
    if (j is Map) {
      return WikiCell(
        (j['t'] ?? '').toString(),
        (j['i'] ?? '').toString(),
        (j['l'] ?? '').toString(),
      );
    }
    return WikiCell(j?.toString() ?? '');
  }
}

/// 区块内的一个内容块：纯文本段落 / 表格 / 图片（三选一）。
///
/// 库街区富文本里既有段落、HTML 表格，也有内嵌图片。表格保留行列结构（[rows]，
/// 每格含文本与可选图标），图片块保留 [imageUrl]，由 UI 分别渲染（真表格 / 图片）。
class WikiBlock {
  final String text; // 文本块内容
  final List<List<WikiCell>> rows; // 表格行
  final String imageUrl; // 图片块 URL

  const WikiBlock._(this.text, this.rows, this.imageUrl);
  const WikiBlock.text(String text) : this._(text, const [], '');
  const WikiBlock.table(List<List<WikiCell>> rows) : this._('', rows, '');
  const WikiBlock.image(String url) : this._('', const [], url);

  bool get isTable => rows.isNotEmpty;
  bool get isImage => imageUrl.isNotEmpty;

  Map<String, dynamic> toJson() {
    if (isImage) return {'type': 'image', 'url': imageUrl};
    if (isTable) {
      return {
        'type': 'table',
        'rows': rows
            .map((r) => r.map((c) => c.toJson()).toList())
            .toList(),
      };
    }
    return {'type': 'text', 'text': text};
  }

  factory WikiBlock.fromCache(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'image':
        return WikiBlock.image((j['url'] ?? '').toString());
      case 'table':
        final rows = (j['rows'] as List?)
                ?.map((r) => (r as List)
                    .map((c) => WikiCell.fromCache(c))
                    .toList())
                .toList() ??
            const <List<WikiCell>>[];
        return WikiBlock.table(rows);
      default:
        return WikiBlock.text((j['text'] ?? '').toString());
    }
  }
}

/// 图鉴词条详情的一个内容区块：标题 + 有序内容块（文本段落 / 表格）。
class WikiSection {
  final String title;
  final List<WikiBlock> blocks;
  const WikiSection({required this.title, this.blocks = const []});

  Map<String, dynamic> toJson() =>
      {'title': title, 'blocks': blocks.map((b) => b.toJson()).toList()};

  factory WikiSection.fromCache(Map<String, dynamic> j) => WikiSection(
        title: (j['title'] ?? '').toString(),
        blocks: (j['blocks'] as List?)
                ?.map((e) => WikiBlock.fromCache(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// 一条角色语音（来自 audio-component 的 mediaList[]）。
class WikiVoice {
  final String title; // 语音标题，如"自我介绍"/"语音1"
  final String url; // 音频播放地址（.wav）
  final String text; // 台词文本（去 HTML）

  const WikiVoice({required this.title, required this.url, this.text = ''});

  Map<String, dynamic> toJson() =>
      {'title': title, 'url': url, if (text.isNotEmpty) 'text': text};

  factory WikiVoice.fromCache(Map<String, dynamic> j) => WikiVoice(
        title: (j['title'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
      );
}

/// 一组语音分类（来自 audio-component 的一个 mediaTab，如"角色台词"/"战斗语音"）。
class WikiVoiceTab {
  final String title;
  final List<WikiVoice> voices;
  const WikiVoiceTab({required this.title, this.voices = const []});

  Map<String, dynamic> toJson() =>
      {'title': title, 'voices': voices.map((v) => v.toJson()).toList()};

  factory WikiVoiceTab.fromCache(Map<String, dynamic> j) => WikiVoiceTab(
        title: (j['title'] ?? '').toString(),
        voices: (j['voices'] as List?)
                ?.map((e) => WikiVoice.fromCache(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// 图鉴词条详情（来自 getEntryDetail 的 data.content）。
class WikiEntryDetail {
  final String name;
  final List<String> infoLines; // 角色基础资料（性别 / 武器 / 属性等）
  final String story; // 角色故事 / 简介（仅角色有，武器/声骸为空）
  final List<String> imageUrls; // 详情内图片
  final List<WikiSection> sections; // 武器/声骸的 basic-component 区块
  final List<WikiVoiceTab> voiceTabs; // 角色语音（audio-component），可空

  const WikiEntryDetail({
    required this.name,
    required this.infoLines,
    required this.story,
    required this.imageUrls,
    this.sections = const [],
    this.voiceTabs = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'infoLines': infoLines,
        'story': story,
        'imageUrls': imageUrls,
        'sections': sections.map((s) => s.toJson()).toList(),
        'voiceTabs': voiceTabs.map((t) => t.toJson()).toList(),
      };

  factory WikiEntryDetail.fromCache(Map<String, dynamic> j) => WikiEntryDetail(
        name: (j['name'] ?? '').toString(),
        infoLines: (j['infoLines'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        story: (j['story'] ?? '').toString(),
        imageUrls: (j['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        sections: (j['sections'] as List?)
                ?.map((e) => WikiSection.fromCache(e as Map<String, dynamic>))
                .toList() ??
            const [],
        voiceTabs: (j['voiceTabs'] as List?)
                ?.map((e) => WikiVoiceTab.fromCache(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
