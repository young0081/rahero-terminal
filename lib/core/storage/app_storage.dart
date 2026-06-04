import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// 本地持久化封装（基于 Hive）。
///
/// 只存简单类型（bool/int/String/Map/List），不依赖代码生成的适配器，
/// 以规避 hive_generator 与新版 analyzer 的版本冲突，并保持构建简单。
///
/// 三个 box：
/// - settings：用户设置（音量、是否跳过开机动画等）
/// - progress：阅读进度 / 飞讯对话进度
/// - assets：资源缓存状态（哪些已下载、校验是否通过）
class AppStorage {
  AppStorage._();

  /// codex 缓存 schema 版本。图鉴解析逻辑有破坏性改动时 +1，
  /// 启动时若存储版本不符则自动清空 codex 缓存（避免旧坏数据被复用）。
  /// v2: 详情解析支持 tabs-component（修表格丢失）+ 扩充 HTML 实体解码（修乱码）。
  /// v3: 表格改为结构化行列（WikiBlock），UI 渲染真表格（彻底修"表格丢失"）。
  /// v4: 详情内嵌图片与表格内图标入模型（WikiCell/图片块），按需下载显示。
  /// v5: 合并相邻同列数表格（修突破素材脱离表格、分裂成独立盒子的问题）。
  /// v6: 单元格保留 <a href> 链接（可点击跳转）+ 垃圾默认标题回退模块名。
  /// v7: entryId 兼容 linkType 2（从 linkUrl 末段提取），修部分声骸"暂无详情"。
  /// v8: 详情解析新增角色语音（audio-component → voiceTabs），旧缓存需重解析。
  static const int _codexSchemaVersion = 8;

  static const String _settingsBox = 'settings';
  static const String _progressBox = 'progress';
  static const String _assetsBox = 'assets';
  static const String _codexBox = 'codex';

  static late Box _settings;
  static late Box _progress;
  static late Box _assets;
  static late Box _codex;

  static bool _initialized = false;

  /// 初始化 Hive，并打开所有 box。在 runApp 之前调用。
  static Future<void> init() async {
    if (_initialized) return;
    // 把 Hive 数据放到应用文档目录，跨平台一致。
    final dir = await getApplicationDocumentsDirectory();
    Hive.init('${dir.path}/rahero_terminal/hive');
    _settings = await Hive.openBox(_settingsBox);
    _progress = await Hive.openBox(_progressBox);
    _assets = await Hive.openBox(_assetsBox);
    _codex = await Hive.openBox(_codexBox);
    await _migrateCodexIfStale();
    _initialized = true;
  }

  /// codex 缓存版本迁移：存储版本与当前 schema 不符时清空缓存。
  /// 用于解析逻辑破坏性升级后，让旧的（可能错误的）缓存自动失效，
  /// 用户无需手动清理即可获得新解析结果。
  /// 同时清空 _assets 的就绪标记，避免旧图片仍被判定为"已就绪"而不重下。
  /// 异常被吞掉（Hive 损坏 / 磁盘满 / 权限问题不应阻断应用启动）。
  static Future<void> _migrateCodexIfStale() async {
    try {
      final stored = _codex.get('_schema_version');
      if (stored is int && stored == _codexSchemaVersion) return;
      await _codex.clear();
      await _assets.clear();
      await _codex.put('_schema_version', _codexSchemaVersion);
    } catch (_) {
      // 迁移失败不应导致启动崩溃；最多保留旧缓存，下次启动再尝试。
    }
  }

  // ---- settings ----
  static T getSetting<T>(String key, T defaultValue) {
    final v = _settings.get(key);
    if (v is T) return v;
    return defaultValue;
  }

  static Future<void> setSetting(String key, Object? value) =>
      _settings.put(key, value);

  // ---- 用户头像（自定义上传）----
  /// 自定义头像文件的本地绝对路径；未设置返回 null。
  static String? getUserAvatarPath() {
    final v = _settings.get('user_avatar_path');
    return v is String && v.isNotEmpty ? v : null;
  }

  static Future<void> setUserAvatarPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _settings.delete('user_avatar_path');
    } else {
      await _settings.put('user_avatar_path', path);
    }
  }

  // ---- progress ----
  static T getProgress<T>(String key, T defaultValue) {
    final v = _progress.get(key);
    if (v is T) return v;
    return defaultValue;
  }

  static Future<void> setProgress(String key, Object? value) =>
      _progress.put(key, value);

  // ---- 飞讯：用户在某会话发出的消息（持久化，重启恢复）----
  /// 取某会话用户已发出的消息列表（每条为 JSON 字符串）。
  static List<String> getSentMessages(String contactId) {
    final v = _progress.get('chat_$contactId');
    if (v is List) {
      return v.whereType<String>().toList();
    }
    return <String>[];
  }

  /// 追加一条用户发出的消息（JSON 字符串）。
  static Future<void> appendSentMessage(
      String contactId, String messageJson) async {
    final list = getSentMessages(contactId);
    list.add(messageJson);
    await _progress.put('chat_$contactId', list);
  }

  /// 清空某会话用户发出的消息。
  static Future<void> clearSentMessages(String contactId) =>
      _progress.delete('chat_$contactId');

  // ---- assets cache state ----
  /// 标记某资源是否已下载并通过校验。
  static bool isAssetReady(String assetId) =>
      _assets.get(assetId, defaultValue: false) == true;

  static Future<void> setAssetReady(String assetId, bool ready) =>
      _assets.put(assetId, ready);

  /// 清空所有资源缓存状态（用于"重新下载"）。
  static Future<void> clearAssetState() => _assets.clear();

  // ---- codex：库街区 wiki 图鉴内容缓存（JSON 索引，与图片文件分离）----
  /// 取某 key 的缓存 JSON 字符串；无则返回 null。
  static String? getCodexJson(String key) {
    final v = _codex.get('json_$key');
    return v is String && v.isNotEmpty ? v : null;
  }

  static Future<void> setCodexJson(String key, String json) =>
      _codex.put('json_$key', json);

  /// 删除某 key 的缓存 JSON（用于更新检测：某条目被官方更新后失效其详情缓存）。
  static Future<void> deleteCodexJson(String key) => _codex.delete('json_$key');

  /// 内容版本标记：用于判断是否需要刷新（库街区返回的版本字段）。
  static String? getCodexVersion(String key) {
    final v = _codex.get('ver_$key');
    return v is String ? v : null;
  }

  static Future<void> setCodexVersion(String key, String version) =>
      _codex.put('ver_$key', version);

  /// 清空图鉴内容缓存（JSON 索引与版本标记；图片文件随 asset 缓存清理）。
  /// 清空后补回 schema 版本标记——否则下次启动 _migrateCodexIfStale 会因读不到
  /// 版本而误判为升级，连带清空 _assets 就绪标记导致图片被迫全量重下。
  static Future<void> clearCodex() async {
    await _codex.clear();
    await _codex.put('_schema_version', _codexSchemaVersion);
  }
}
