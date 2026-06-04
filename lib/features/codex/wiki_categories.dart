/// 库街区图鉴分类。首批覆盖共鸣者 / 武器 / 声骸。
///
/// catalogueId 为内置兜底值（实测自 getTree）；运行时优先用 [resolveFromTree]
/// 按分类名从目录树动态解析，避免库街区调整目录后硬编码失效。
enum WikiCategory {
  resonator('共鸣者', '1105'),
  weapon('武器', '1106'),
  echo('声骸', '1107');

  final String displayName;
  final String fallbackId;
  const WikiCategory(this.displayName, this.fallbackId);
}

/// 在 getTree 返回的目录树里按分类名递归查找其 id；找不到返回兜底值。
///
/// 树结构：`data` 根节点含 `children[]`，每个节点有 `name` 与 `id`/`key`，
/// 可多层嵌套（如 全部 → 游戏图鉴 → 共鸣者）。
String resolveCategoryId(Map<String, dynamic>? tree, WikiCategory category) {
  if (tree == null) return category.fallbackId;
  final found = _findIdByName(tree, category.displayName);
  return found ?? category.fallbackId;
}

String? _findIdByName(dynamic node, String name) {
  if (node is Map) {
    if (node['name'] == name) {
      final id = node['id'] ?? node['key'];
      if (id != null) return id.toString();
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        final r = _findIdByName(child, name);
        if (r != null) return r;
      }
    }
  } else if (node is List) {
    for (final child in node) {
      final r = _findIdByName(child, name);
      if (r != null) return r;
    }
  }
  return null;
}
