import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'ugc_script_editor.dart';
import 'ugc_script_service.dart';

/// UGC 剧本列表页面
class UGCScriptListScreen extends ConsumerWidget {
  const UGCScriptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptsAsync = ref.watch(ugcScriptsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('我的剧本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.input),
            onPressed: () => _importShareCode(context, ref),
            tooltip: '导入分享码',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
            tooltip: '使用说明',
          ),
        ],
      ),
      body: SafeArea(
        child: scriptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              '加载失败：$e',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          data: (scripts) => scripts.isEmpty
              ? _EmptyState(onCreateNew: () => _createNew(context))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDimens.gapMd),
                  itemCount: scripts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final script = scripts[index];
                    return _ScriptCard(
                      script: script,
                      onEdit: () => _edit(context, script),
                      onDelete: () => _delete(context, ref, script),
                      onExport: () => _export(context, ref, script),
                      onCopyShareCode: () =>
                          _copyShareCode(context, ref, script),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context),
        backgroundColor: AppColors.coolAccent,
        icon: const Icon(Icons.add),
        label: const Text('创建剧本'),
      ),
    );
  }

  Future<void> _copyShareCode(
    BuildContext context,
    WidgetRef ref,
    UGCScript script,
  ) async {
    final service = ref.read(ugcScriptServiceProvider);
    final code = service.exportShareCode(script);
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享码已复制到剪贴板')));
    }
  }

  Future<void> _importShareCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('导入分享码', style: TextStyle(color: AppColors.silver)),
        content: TextField(
          controller: controller,
          maxLines: 6,
          minLines: 3,
          style: const TextStyle(color: AppColors.silver, fontSize: 13),
          decoration: InputDecoration(
            hintText: '粘贴 RAHERO-UGC-v1: 开头的分享码',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              controller.text = data?.text ?? '';
            },
            child: const Text(
              '从剪贴板粘贴',
              style: TextStyle(color: AppColors.coolAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;

    final service = ref.read(ugcScriptServiceProvider);
    final script = await service.importFromShareText(text);
    if (script == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('分享码无效，无法导入'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final imported = await service.importAndSave(script);
    ref.invalidate(ugcScriptsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导入剧本：${imported.title}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _createNew(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UGCScriptEditorScreen()));
  }

  void _edit(BuildContext context, UGCScript script) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UGCScriptEditorScreen(editingScript: script),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UGCScript script,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认删除', style: TextStyle(color: AppColors.silver)),
        content: Text(
          '确定要删除剧本"${script.title}"吗？此操作无法撤销。',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(ugcScriptServiceProvider);
      await service.delete(script.id);
      ref.invalidate(ugcScriptsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('剧本已删除'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    UGCScript script,
  ) async {
    try {
      final service = ref.read(ugcScriptServiceProvider);
      final filePath = await service.exportToFile(script);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              '导出成功',
              style: TextStyle(color: AppColors.silver),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '剧本已导出到：',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(AppDimens.gapSm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(
                      color: AppColors.silver,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '你可以将此文件分享给其他人，他们可以导入使用。',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: filePath));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('路径已复制到剪贴板')));
                },
                child: const Text(
                  '复制路径',
                  style: TextStyle(color: AppColors.coolAccent),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '关闭',
                  style: TextStyle(color: AppColors.silver),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('使用说明', style: TextStyle(color: AppColors.silver)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '什么是 UGC 剧本？',
                style: TextStyle(
                  color: AppColors.coolAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '你可以创作自己的飞讯对话剧本，编写角色之间的互动故事。',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '如何创作？',
                style: TextStyle(
                  color: AppColors.coolAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '1. 点击"创建剧本"按钮\n2. 填写剧本标题和作者\n3. 添加对话，设置说话者和内容\n4. 保存即可',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '如何分享？',
                style: TextStyle(
                  color: AppColors.coolAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '点击剧本卡片的"复制分享码"可以直接把剧本复制到聊天软件。也可以导出 JSON 文件做备份。',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '知道了',
              style: TextStyle(color: AppColors.coolAccent),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateNew;
  const _EmptyState({required this.onCreateNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_note,
            size: 80,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有创作任何剧本',
            style: TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreateNew,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coolAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('创建第一个剧本', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

/// 剧本卡片
class _ScriptCard extends StatelessWidget {
  final UGCScript script;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onCopyShareCode;

  const _ScriptCard({
    required this.script,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.onCopyShareCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.gapMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      script.title,
                      style: const TextStyle(
                        color: AppColors.silver,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '作者：${script.author}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.steel),
                color: AppColors.surfaceHigh,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'export':
                      onExport();
                      break;
                    case 'share':
                      onCopyShareCode();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: AppColors.steel),
                        SizedBox(width: 8),
                        Text('编辑', style: TextStyle(color: AppColors.silver)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18, color: AppColors.coolAccent),
                        SizedBox(width: 8),
                        Text(
                          '复制分享码',
                          style: TextStyle(color: AppColors.silver),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(
                          Icons.upload,
                          size: 18,
                          color: AppColors.coolAccent,
                        ),
                        SizedBox(width: 8),
                        Text('导出', style: TextStyle(color: AppColors.silver)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: AppColors.silver)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  '${script.messages.length} 条对话',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(script.createdAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
