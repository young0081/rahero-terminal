/// 单个资源条目（对应 asset_manifest.json 中 assets[] 的一项）。
class AssetEntry {
  final String id;
  final String name;
  final String category; // boot / faction
  final String type; // video / gif / png_seq
  final String source; // 相对 baseUrl 的路径
  final String cache; // 相对缓存根目录的路径
  final String checksum; // sha256，空字符串表示暂不校验

  const AssetEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.source,
    required this.cache,
    required this.checksum,
  });

  factory AssetEntry.fromJson(Map<String, dynamic> json) {
    return AssetEntry(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      category: json['category'] as String? ?? 'faction',
      type: json['type'] as String? ?? 'video',
      source: json['source'] as String,
      cache: json['cache'] as String,
      checksum: json['checksum'] as String? ?? '',
    );
  }

  bool get hasChecksum => checksum.trim().isNotEmpty;
}

/// 整份资源清单。
class AssetManifest {
  final int manifestVersion;
  final String baseUrl;
  final List<AssetEntry> assets;

  const AssetManifest({
    required this.manifestVersion,
    required this.baseUrl,
    required this.assets,
  });

  factory AssetManifest.fromJson(Map<String, dynamic> json) {
    final list = (json['assets'] as List<dynamic>? ?? [])
        .map((e) => AssetEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return AssetManifest(
      manifestVersion: json['manifestVersion'] as int? ?? 1,
      baseUrl: (json['baseUrl'] as String? ?? '').trimRight(),
      assets: list,
    );
  }

  /// 下载地址是否已配置（上线前为占位地址）。
  bool get isBaseUrlConfigured =>
      baseUrl.isNotEmpty && !baseUrl.contains('REPLACE_WITH');

  AssetEntry? byId(String id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<AssetEntry> get factions =>
      assets.where((a) => a.category == 'faction').toList();

  AssetEntry? get boot {
    for (final a in assets) {
      if (a.category == 'boot') return a;
    }
    return null;
  }
}
