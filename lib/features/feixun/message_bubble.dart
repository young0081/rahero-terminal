import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 消息气泡悬停增强：桌面端鼠标悬停时轻微放大 + 边框高亮。
class MessageBubble extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final BoxDecoration decoration;

  const MessageBubble({
    super.key,
    required this.child,
    required this.isMe,
    required this.decoration,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 桌面端启用悬停增强，移动端禁用。
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return MouseRegion(
      onEnter: isDesktop ? (_) => setState(() => _isHovered = true) : null,
      onExit: isDesktop ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: _isHovered
              ? widget.decoration.copyWith(
                  border: Border.all(
                    color: widget.isMe
                        ? AppColors.coolAccent.withValues(alpha: 0.8)
                        : AppColors.steel.withValues(alpha: 0.9),
                    width: widget.isMe ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isMe
                          ? AppColors.coolAccent.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.12),
                      blurRadius: widget.isMe ? 12 : 8,
                      spreadRadius: widget.isMe ? 1 : 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : widget.decoration,
          child: widget.child,
        ),
      ),
    );
  }
}
