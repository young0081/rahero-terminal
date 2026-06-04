import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/storage/app_storage.dart';

/// UGC 剧本数据
class UGCScript {
  final String id;
  final String title;
  final String author;
  final DateTime createdAt;
  final List<UGCMessage> messages;

  const UGCScript({
    required this.id,
    required this.title,
    required this.author,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory UGCScript.fromJson(Map<String, dynamic> j) => UGCScript(
    id: j['id'] as String,
    title: j['title'] as String? ?? '未命名剧本',
    author: j['author'] as String? ?? '匿名',
    createdAt: DateTime.parse(j['createdAt'] as String),
    messages:
        (j['messages'] as List<dynamic>?)
            ?.map((m) => UGCMessage.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

/// UGC 消息
class UGCMessage {
  final String speaker; // 说话者名字
  final String content; // 内容
  final String type; // text / emoji

  const UGCMessage({
    required this.speaker,
    required this.content,
    this.type = 'text',
  });

  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'content': content,
    'type': type,
  };

  factory UGCMessage.fromJson(Map<String, dynamic> j) => UGCMessage(
    speaker: j['speaker'] as String,
    content: j['content'] as String,
    type: j['type'] as String? ?? 'text',
  );
}

/// UGC 剧本服务
class UGCScriptService {
  static const _storageKey = 'ugc_scripts';
  static const _sharePrefix = 'RAHERO-UGC-v1:';

  /// 获取所有剧本
  Future<List<UGCScript>> getAll() async {
    final jsonStr = AppStorage.getSetting<String>(_storageKey, '[]');
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((j) => UGCScript.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// 保存剧本
  Future<void> save(UGCScript script) async {
    final all = await getAll();
    final index = all.indexWhere((s) => s.id == script.id);
    if (index >= 0) {
      all[index] = script;
    } else {
      all.add(script);
    }
    await AppStorage.setSetting(
      _storageKey,
      jsonEncode(all.map((s) => s.toJson()).toList()),
    );
  }

  /// 删除剧本
  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((s) => s.id == id);
    await AppStorage.setSetting(
      _storageKey,
      jsonEncode(all.map((s) => s.toJson()).toList()),
    );
  }

  /// 导出为 JSON 文件
  Future<String> exportToFile(UGCScript script) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/拉海洛终端/UGC剧本');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }

    final fileName = '${script.title}_${script.id}.json';
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(jsonEncode(script.toJson()));
    return file.path;
  }

  /// 从 JSON 导入
  Future<UGCScript?> importFromJson(String jsonStr) async {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UGCScript.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 生成可复制到聊天软件中的分享码。
  String exportShareCode(UGCScript script) {
    final payload = utf8.encode(jsonEncode(script.toJson()));
    return '$_sharePrefix${base64Url.encode(payload)}';
  }

  /// 从分享码解析剧本。兼容直接粘贴 JSON，方便调试和手动导入。
  Future<UGCScript?> importFromShareText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{')) return importFromJson(trimmed);
    if (!trimmed.startsWith(_sharePrefix)) return null;
    try {
      final body = trimmed.substring(_sharePrefix.length).trim();
      final jsonStr = utf8.decode(base64Url.decode(body));
      return importFromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  /// 保存导入剧本。保留原标题/作者/消息，生成新 id 避免覆盖本地同名剧本。
  Future<UGCScript> importAndSave(UGCScript script) async {
    final imported = UGCScript(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: script.title.endsWith('（导入）')
          ? script.title
          : '${script.title}（导入）',
      author: script.author,
      createdAt: DateTime.now(),
      messages: script.messages,
    );
    await save(imported);
    return imported;
  }
}

/// UGC 服务 Provider
final ugcScriptServiceProvider = Provider<UGCScriptService>(
  (ref) => UGCScriptService(),
);

/// 所有剧本 Provider
final ugcScriptsProvider = FutureProvider<List<UGCScript>>((ref) async {
  final service = ref.watch(ugcScriptServiceProvider);
  return service.getAll();
});
