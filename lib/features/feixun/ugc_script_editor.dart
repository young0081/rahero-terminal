import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../achievements/achievement_trigger.dart';
import 'ugc_script_service.dart';

/// UGC 剧本编辑器界面
class UGCScriptEditorScreen extends ConsumerStatefulWidget {
  final UGCScript? editingScript; // 如果为 null 则创建新剧本

  const UGCScriptEditorScreen({super.key, this.editingScript});

  @override
  ConsumerState<UGCScriptEditorScreen> createState() => _UGCScriptEditorScreenState();
}

class _UGCScriptEditorScreenState extends ConsumerState<UGCScriptEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  final List<UGCMessage> _messages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.editingScript?.title ?? '');
    _authorController = TextEditingController(text: widget.editingScript?.author ?? '');
    if (widget.editingScript != null) {
      _messages.addAll(widget.editingScript!.messages);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _addMessage() {
    showDialog(
      context: context,
      builder: (context) => _MessageEditDialog(
        onSave: (msg) {
          setState(() => _messages.add(msg));
        },
      ),
    );
  }

  void _editMessage(int index) {
    showDialog(
      context: context,
      builder: (context) => _MessageEditDialog(
        message: _messages[index],
        onSave: (msg) {
          setState(() => _messages[index] = msg);
        },
      ),
    );
  }

  void _deleteMessage(int index) {
    setState(() => _messages.removeAt(index));
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _messages[index];
        _messages[index] = _messages[index - 1];
        _messages[index - 1] = temp;
      });
    }
  }

  void _moveDown(int index) {
    if (index < _messages.length - 1) {
      setState(() {
        final temp = _messages[index];
        _messages[index] = _messages[index + 1];
        _messages[index + 1] = temp;
      });
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入剧本标题'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剧本至少需要一条消息'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSaving = true);

    final script = UGCScript(
      id: widget.editingScript?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      author: _authorController.text.trim().isEmpty ? '匿名' : _authorController.text.trim(),
      createdAt: widget.editingScript?.createdAt ?? DateTime.now(),
      messages: _messages,
    );

    final service = ref.read(ugcScriptServiceProvider);
    await service.save(script);
    ref.invalidate(ugcScriptsProvider);

    // 触发成就
    final allScripts = await service.getAll();
    if (mounted) {
      AchievementTrigger(ref, context: context).onCreateUGCScript(allScripts.length);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剧本保存成功！'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.editingScript == null ? '创建剧本' : '编辑剧本'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coolAccent),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: '保存剧本',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 基本信息
            Container(
              padding: const EdgeInsets.all(AppDimens.gapMd),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: AppColors.silver, fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: '剧本标题',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      hintText: '给你的剧本起个名字',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.coolAccent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _authorController,
                    style: const TextStyle(color: AppColors.silver, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: '作者（选填）',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      hintText: '留空则显示"匿名"',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.coolAccent, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 消息列表
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('还没有任何对话', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('点击右下角按钮添加', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(AppDimens.gapMd),
                      itemCount: _messages.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _messages.removeAt(oldIndex);
                          _messages.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _MessageCard(
                          key: ValueKey('msg_$index'),
                          message: msg,
                          index: index,
                          onEdit: () => _editMessage(index),
                          onDelete: () => _deleteMessage(index),
                          onMoveUp: index > 0 ? () => _moveUp(index) : null,
                          onMoveDown: index < _messages.length - 1 ? () => _moveDown(index) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMessage,
        backgroundColor: AppColors.coolAccent,
        icon: const Icon(Icons.add),
        label: const Text('添加对话'),
      ),
    );
  }
}

/// 消息卡片
class _MessageCard extends StatelessWidget {
  final UGCMessage message;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _MessageCard({
    super.key,
    required this.message,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.coolAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: AppColors.coolAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.speaker,
                  style: const TextStyle(color: AppColors.silver, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: AppColors.steel,
                onPressed: onEdit,
                tooltip: '编辑',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                color: AppColors.danger,
                onPressed: onDelete,
                tooltip: '删除',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.content,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 消息编辑对话框
class _MessageEditDialog extends StatefulWidget {
  final UGCMessage? message;
  final void Function(UGCMessage) onSave;

  const _MessageEditDialog({this.message, required this.onSave});

  @override
  State<_MessageEditDialog> createState() => _MessageEditDialogState();
}

class _MessageEditDialogState extends State<_MessageEditDialog> {
  late TextEditingController _speakerController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _speakerController = TextEditingController(text: widget.message?.speaker ?? '');
    _contentController = TextEditingController(text: widget.message?.content ?? '');
  }

  @override
  void dispose() {
    _speakerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    if (_speakerController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('说话者和内容不能为空'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final msg = UGCMessage(
      speaker: _speakerController.text.trim(),
      content: _contentController.text.trim(),
    );
    widget.onSave(msg);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.gapLg),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message == null ? '添加对话' : '编辑对话',
              style: const TextStyle(color: AppColors.silver, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _speakerController,
              style: const TextStyle(color: AppColors.silver),
              decoration: const InputDecoration(
                labelText: '说话者',
                labelStyle: TextStyle(color: AppColors.textMuted),
                hintText: '例如：今汐、秧秧',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.coolAccent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              style: const TextStyle(color: AppColors.silver),
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '对话内容',
                labelStyle: TextStyle(color: AppColors.textMuted),
                hintText: '输入对话内容...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.coolAccent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coolAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
