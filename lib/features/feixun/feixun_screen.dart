import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../achievements/achievement_trigger.dart';
import '../codex/voice_player.dart';
import 'affection_service.dart';
import 'chat_background.dart';
import 'chat_session.dart';
import 'emoji_view.dart';
import 'feixun_avatar.dart';
import 'feixun_data.dart';
import 'message_bubble.dart';
import 'time_formatter.dart';
import 'waveform_painter.dart';

/// 飞讯页：左/上为会话列表，点击进入聊天界面（占位剧本内容）。
/// 还原游戏内飞讯的聊天气泡观感。
class FeixunScreen extends ConsumerWidget {
  const FeixunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feixunContactsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stackTrace) => Center(
        child: Text('飞讯加载失败：$e',
            style: const TextStyle(color: AppColors.danger)),
      ),
      data: (contacts) => ListView.separated(
        padding: const EdgeInsets.all(AppDimens.gapSm),
        itemCount: contacts.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, i) {
          final c = contacts[i];
          return _ContactListTile(contact: c);
        },
      ),
    );
  }
}

/// 联系人列表项（带好感度显示）
class _ContactListTile extends ConsumerWidget {
  final FeixunContact contact;
  const _ContactListTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final affectionAsync = ref.watch(contactAffectionProvider(contact.id));

    return ListTile(
      leading: FeixunAvatar(
          assetId: contact.avatarAssetId, label: contact.name, size: 48),
      title: Row(
        children: [
          if (contact.pinned)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 14, color: AppColors.coolAccent),
            ),
          Expanded(
            child: Text(contact.name,
                style: const TextStyle(
                    color: AppColors.silver, fontWeight: FontWeight.w500)),
          ),
          // 好感度等级标签
          affectionAsync.when(
            data: (affection) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getAffectionColor(affection.level.level)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getAffectionColor(affection.level.level)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                affection.level.title,
                style: TextStyle(
                  color: _getAffectionColor(affection.level.level),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
      ),
      subtitle: Text(contact.lastPreview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ChatView(contact: contact),
      )),
    );
  }

  Color _getAffectionColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.pink;
      case 5:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

class _ChatView extends ConsumerStatefulWidget {
  final FeixunContact contact;
  const _ChatView({required this.contact});

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _searchInput = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  bool _emojiOpen = false;
  bool _searchOpen = false;
  bool _showScrollButton = false;
  String _searchQuery = '';
  late final ChatLog _log;

  @override
  void initState() {
    super.initState();
    _log = ChatLog.load(widget.contact);
    _log.onChanged = () {
      if (mounted) setState(() {});
    };
    // 模拟弱网下同步会话历史（接收加载态），完成后滚到底部。
    _log.connect().then((_) => _scrollToBottom());

    // 监听滚动位置，控制"滚动到底部"按钮显示
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final isAtBottom = _scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 100;
    if (_showScrollButton == isAtBottom) {
      setState(() => _showScrollButton = !isAtBottom);
    }

    // 上滑到顶部时触发加载更多历史
    if (_scroll.position.pixels <= 100 && _log.hasMoreHistory && !_log.isLoadingMore) {
      _log.loadMoreHistory();
    }
  }

  @override
  void dispose() {
    _log.onChanged = null;
    _input.dispose();
    _searchInput.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // 下一帧滚到底部（新消息可见）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _scrollToBottom();
    await _log.sendText(text); // 状态流转由 onChanged 驱动刷新
    _scrollToBottom();
    // 增加好感度
    _addAffection();
  }

  Future<void> _sendEmoji(String emojiId) async {
    _scrollToBottom();
    await _log.sendEmoji(emojiId);
    _scrollToBottom();
    // 增加好感度
    _addAffection();
  }

  void _addAffection() {
    // 异步增加好感度，不阻塞UI
    final service = ref.read(affectionServiceProvider);
    service.addPoints(widget.contact.id, 2).then((data) {
      // 检查是否升级
      final prevLevel = affectionLevels.firstWhere(
        (l) => l.requiredPoints <= data.points - 2,
        orElse: () => affectionLevels[0],
      );
      final currentLevel = data.level;
      if (currentLevel.level > prevLevel.level && mounted) {
        // 好感度升级，显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.pinkAccent, size: 20),
                const SizedBox(width: 8),
                Text('与 ${widget.contact.name} 的好感度提升至「${currentLevel.title}」！'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        // 触发好感度成就
        AchievementTrigger(ref).onAffectionLevelUp(currentLevel.level);
      }
    });
  }

  Future<void> _retry(String messageId) async {
    await _log.retry(messageId);
  }

  Future<void> _clearMine() async {
    await _log.clearMine();
  }

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) {
      _inputFocus.unfocus();
    } else {
      _inputFocus.requestFocus();
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchInput.clear();
        _searchQuery = '';
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query.toLowerCase());
  }

  bool _messageMatchesSearch(FeixunMessage msg) {
    if (_searchQuery.isEmpty) return false;
    if (msg.type == 'text') {
      return msg.content.toLowerCase().contains(_searchQuery);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final messages = _log.messages;
    // 历史加载中且暂无消息：整页加载占位。
    final showHistoryLoader = _log.isLoadingHistory && messages.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.contact.name),
        actions: [
          IconButton(
            tooltip: '搜索消息',
            icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: '清空我发送的消息',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearMine,
          ),
        ],
      ),
      body: SafeArea(
        child: ChatBackground(
          showParticles: true,
          child: Column(
            children: [
              // 搜索栏（折叠展开）
              if (_searchOpen)
                Container(
                  padding: const EdgeInsets.all(AppDimens.gapSm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _searchInput,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.silver, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索消息内容…',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.steel),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              color: AppColors.steel,
                              onPressed: () {
                                _searchInput.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.gapSm, vertical: AppDimens.gapSm),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                        borderSide:
                            BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                        borderSide:
                            const BorderSide(color: AppColors.coolAccent, width: 1.5),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    showHistoryLoader
                        ? const _HistoryLoader()
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(AppDimens.gapMd),
                            // 顶部加载更多指示器 + 历史消息 + 尾部"接收中"打字指示
                            itemCount: (_log.isLoadingMore ? 1 : 0) +
                                messages.length +
                                (_log.isLoadingHistory ? 1 : 0),
                            itemBuilder: (context, i) {
                              // 顶部加载更多指示器
                              if (_log.isLoadingMore && i == 0) {
                                return const Padding(
                                  padding: EdgeInsets.all(AppDimens.gapMd),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.coolAccent),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final msgIndex =
                                  i - (_log.isLoadingMore ? 1 : 0);
                              // 尾部"接收中"打字指示
                              if (msgIndex >= messages.length) {
                                return _TypingIndicatorRow(
                                  key: const ValueKey('typing_indicator'),
                                  contact: widget.contact,
                                );
                              }
                              final msg = messages[msgIndex];
                              return _MessageRow(
                                key: ValueKey(msg.id),
                                message: msg,
                                contact: widget.contact,
                                onRetry: _retry,
                                highlighted: _messageMatchesSearch(msg),
                              );
                            },
                          ),
                    // 滚动到底部按钮
                    if (_showScrollButton)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: AppColors.coolAccent,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.arrow_downward,
                              color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              _InputBar(
                controller: _input,
                focusNode: _inputFocus,
                emojiOpen: _emojiOpen,
                onToggleEmoji: _toggleEmoji,
                onSend: _sendText,
              ),
              if (_emojiOpen) _EmojiPanel(onPick: _sendEmoji),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部输入栏：表情按钮 + 文本输入框 + 发送键。
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool emojiOpen;
  final VoidCallback onToggleEmoji;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.emojiOpen,
    required this.onToggleEmoji,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surface.withValues(alpha: 0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(
          top: BorderSide(
            color: AppColors.coolAccent,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gapMd, vertical: AppDimens.gapSm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: '表情',
            icon: Icon(
              widget.emojiOpen
                  ? Icons.keyboard
                  : Icons.emoji_emotions_outlined,
              color:
                  widget.emojiOpen ? AppColors.coolAccent : AppColors.steel,
            ),
            onPressed: widget.onToggleEmoji,
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) {
                return Container(
                  decoration: _isFocused
                      ? BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.coolAccent
                                  .withValues(alpha: _glowAnim.value),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: child,
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  style:
                      const TextStyle(color: AppColors.silver, fontSize: 15),
                  cursorColor: AppColors.coolAccent,
                  decoration: InputDecoration(
                    hintText: '发送消息…',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceHigh,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.gapMd,
                        vertical: AppDimens.gapSm + 2),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
                      borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
                      borderSide: const BorderSide(
                          color: AppColors.coolAccent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.gapSm),
          // 发送键：渐变按钮 + 外发光
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C9FF), Color(0xFF0099CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coolAccent.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                onTap: widget.onSend,
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child:
                      Icon(Icons.send, size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表情栏：网格展示表情，点击发送。表情贴图运行时从库街区下载，未就绪用字形。
class _EmojiPanel extends ConsumerWidget {
  final void Function(String emojiId) onPick;
  const _EmojiPanel({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feixunEmojisProvider);
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('表情加载失败：$e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (emojis) => GridView.builder(
          padding: const EdgeInsets.all(AppDimens.gapSm),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 56,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, i) {
            final e = emojis[i];
            return InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              onTap: () => onPick(e.id),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: EmojiView(emojiId: e.id, glyph: e.glyph, size: 36),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 单条消息行：对方消息头像在左、我方消息头像在右，双方都显示头像。
/// 新气泡带出现过渡动画；我方消息按状态显示发送中 / 失败重试。
class _MessageRow extends ConsumerStatefulWidget {
  final FeixunMessage message;
  final FeixunContact contact;
  final Future<void> Function(String messageId)? onRetry;
  final bool highlighted; // 搜索高亮

  const _MessageRow({
    super.key,
    required this.message,
    required this.contact,
    this.onRetry,
    this.highlighted = false,
  });

  @override
  ConsumerState<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<_MessageRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _rotationAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    // 仅表情消息触发动画
    if (widget.message.isEmoji) {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    // 气泡最大宽度：屏宽的约 64%，避免长消息铺满整行，保留聊天观感。
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.64;

    final Widget bubbleContent;
    if (m.isEmoji) {
      // 表情消息：固定基线尺寸 + contain，完整不裁剪 + 旋转缩放动画。
      final emojiMap = ref.watch(emojiByIdProvider).asData?.value;
      final glyph = emojiMap?[m.content]?.glyph ?? '🙂';
      bubbleContent = ScaleTransition(
        scale: _scaleAnim,
        child: RotationTransition(
          turns: _rotationAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: EmojiView(emojiId: m.content, glyph: glyph, size: 56),
          ),
        ),
      );
    } else if (m.isImage) {
      // 图片消息：圆角图片 + 点击查看大图（占位）
      bubbleContent = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxBubbleWidth,
          maxHeight: 300,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          child: Image.network(
            m.content,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 200,
              height: 150,
              color: AppColors.surfaceHigh,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined,
                      color: AppColors.textMuted, size: 48),
                  SizedBox(height: 8),
                  Text('图片加载失败',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: AppColors.surfaceHigh,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.coolAccent),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (m.isVoice) {
      // 语音消息：播放按钮 + 波形占位 + 时长
      final duration = m.metadata?['duration'] as String? ?? '0:00';
      final voicePlayer = ref.watch(voicePlayerProvider);
      final isPlaying = voicePlayer.playingUrl == m.content;
      final isLoading = isPlaying && voicePlayer.loading;

      bubbleContent = InkWell(
        onTap: () => ref.read(voicePlayerProvider.notifier).toggle(m.content),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth * 0.7),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.gapMd, vertical: AppDimens.gapSm),
          decoration: BoxDecoration(
            color: m.isMe
                ? AppColors.coolAccent.withValues(alpha: 0.2)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            border: Border.all(
              color: m.isMe
                  ? AppColors.coolAccent.withValues(alpha: 0.4)
                  : AppColors.border.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        m.isMe ? AppColors.coolAccent : AppColors.steel),
                  ),
                )
              else
                Icon(
                    isPlaying
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: m.isMe ? AppColors.coolAccent : AppColors.steel,
                    size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  size: const Size(double.infinity, 24),
                  painter: WaveformPainter(
                      color: m.isMe ? AppColors.coolAccent : AppColors.steel),
                ),
              ),
              const SizedBox(width: 8),
              Text(duration,
                  style: TextStyle(
                      color: m.isMe ? AppColors.silver : AppColors.textMuted,
                      fontSize: 12)),
            ],
          ),
        ),
      );
    } else if (m.isFile) {
      // 文件消息：图标 + 文件名 + 大小
      final fileName = m.metadata?['fileName'] as String? ?? '未知文件';
      final fileSize = m.metadata?['fileSize'] as String? ?? '';
      bubbleContent = Container(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        padding: const EdgeInsets.all(AppDimens.gapMd),
        decoration: BoxDecoration(
          color: m.isMe ? AppColors.coolAccent.withValues(alpha: 0.15) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(
            color: m.isMe
                ? AppColors.coolAccent.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                color: m.isMe ? AppColors.coolAccent : AppColors.steel, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fileName,
                      style: TextStyle(
                          color: m.isMe ? Colors.white : AppColors.silver,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (fileSize.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(fileSize,
                        style: TextStyle(
                            color: m.isMe ? AppColors.textMuted : AppColors.textMuted,
                            fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 文本气泡：渐变背景 + 微光边框 + 内阴影层次。
      final bubbleDecoration = m.isMe
          ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A4A6F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              border: Border.all(
                color: AppColors.coolAccent.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coolAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            );

      bubbleContent = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: MessageBubble(
          isMe: m.isMe,
          decoration: bubbleDecoration.copyWith(
            // 搜索高亮：添加黄色边框
            border: widget.highlighted
                ? Border.all(
                    color: const Color(0xFFFFD700), // 金色高亮
                    width: 2.5,
                  )
                : bubbleDecoration.border,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.gapMd + 2, vertical: AppDimens.gapSm + 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(m.content,
                    softWrap: true,
                    style: TextStyle(
                        color: m.isMe ? Colors.white : AppColors.silver,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 4),
                // 时间戳 + 已读状态：霓虹风格微光
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(TimeFormatter.format(m.time),
                          style: TextStyle(
                              color: m.isMe
                                  ? AppColors.coolAccent.withValues(alpha: 0.9)
                                  : AppColors.textMuted,
                              fontSize: 10,
                              letterSpacing: 0.5)),
                    ),
                    if (m.isMe && m.isSent) ...[
                      const SizedBox(width: 4),
                      Icon(
                        m.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: m.isRead
                            ? AppColors.coolAccent
                            : AppColors.textMuted,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 我方消息：根据状态附加发送中 / 失败重试指示。
    final statusIndicator = m.isMe ? _statusIndicator(m) : null;

    final bubbleWithStatus = statusIndicator == null
        ? bubbleContent
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              statusIndicator,
              const SizedBox(width: 6),
              Flexible(child: bubbleContent),
            ],
          );

    final bubble = Flexible(child: bubbleWithStatus);

    final avatar = m.isMe
        ? const SelfAvatar(size: 40)
        : FeixunAvatar(
            assetId: widget.contact.avatarAssetId,
            label: widget.contact.name,
            size: 40);

    final children = m.isMe
        ? [bubble, const SizedBox(width: AppDimens.gapSm), avatar]
        : [avatar, const SizedBox(width: AppDimens.gapSm), bubble];

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            m.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    // 出现过渡动画：淡入 + 轻微上移 + 缩放（更立体的出现效果）。
    return TweenAnimationBuilder<double>(
      key: ValueKey('anim_${m.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: Transform.scale(
            scale: 0.92 + t * 0.08,
            child: child,
          ),
        ),
      ),
      child: row,
    );
  }

  Widget? _statusIndicator(FeixunMessage m) {
    if (m.isSending) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.textMuted),
      );
    }
    if (m.isFailed) {
      return InkWell(
        onTap: widget.onRetry == null ? null : () => widget.onRetry!(m.id),
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        child: const Tooltip(
          message: '发送失败，点击重试',
          child: Icon(Icons.error_outline, size: 18, color: AppColors.danger),
        ),
      );
    }
    return null;
  }
}

/// 会话历史加载占位（模拟弱网下接收消息需要加载时整页显示）。
class _HistoryLoader extends StatelessWidget {
  const _HistoryLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.coolAccent),
          ),
          SizedBox(height: AppDimens.gapSm),
          Text('正在接收消息…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 对方「正在输入 / 接收中」打字指示气泡：三点循环跳动动画。
class _TypingIndicatorRow extends StatelessWidget {
  final FeixunContact contact;
  const _TypingIndicatorRow({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeixunAvatar(
              assetId: contact.avatarAssetId, label: contact.name, size: 40),
          const SizedBox(width: AppDimens.gapSm),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.gapMd + 2,
                vertical: AppDimens.gapSm + 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              border: Border.all(
                color: AppColors.coolAccent.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coolAccent.withValues(alpha: 0.1),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

/// 三点跳动动画。
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // 每个点相位错开，形成依次跳动。
            final phase = (_c.value - i * 0.18) % 1.0;
            final lift = phase < 0.5 ? (0.5 - phase) * 2 : 0.0;
            final alpha = 0.3 + lift * 0.7;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, -lift * 4),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.coolAccent.withValues(alpha: alpha),
                        AppColors.coolAccent.withValues(alpha: alpha * 0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coolAccent.withValues(alpha: lift * 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
