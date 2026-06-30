import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../models/chat_message.dart';
import '../app_theme.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _showSql = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── Role label ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 4,
              right: isUser ? 4 : 0,
              bottom: 4,
            ),
            child: Text(
              isUser ? 'You' : 'AskBase',
              style: AppTextStyles.caption.copyWith(
                color: isUser ? AppColors.textMuted : AppColors.accent,
              ),
            ),
          ),

          // ── Bubble ─────────────────────────────────────────────────────
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88,
            ),
            decoration: BoxDecoration(
              color: isUser ? AppColors.userBubble : AppColors.assistantBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser
                    ? AppColors.accentDim.withOpacity(0.5)
                    : AppColors.textMuted.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: isUser
                      ? Text(msg.content, style: AppTextStyles.body)
                      : _AssistantContent(
                          content: msg.content,
                          state: msg.state,
                        ),
                ),

                // ── SQL disclosure (assistant only) ──────────────────────
                if (!isUser && msg.generatedSql != null) ...[
                  Divider(
                    height: 1,
                    color: AppColors.textMuted.withOpacity(0.15),
                  ),
                  _SqlDisclosure(
                    sql: msg.generatedSql!,
                    isExpanded: _showSql,
                    onToggle: () => setState(() => _showSql = !_showSql),
                  ),
                ],
              ],
            ),
          ),

          // ── Timestamp ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 4,
              right: isUser ? 4 : 0,
            ),
            child: Text(
              DateFormat('h:mm a').format(msg.timestamp),
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assistant content with streaming cursor ───────────────────────────────────

class _AssistantContent extends StatelessWidget {
  final String content;
  final MessageState state;

  const _AssistantContent({required this.content, required this.state});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final isStreaming = state == MessageState.streaming;

    return MarkdownBody(
      data: content + (isStreaming ? ' ▍' : ''),
      styleSheet: MarkdownStyleSheet(
        p: AppTextStyles.body,
        strong: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        em: AppTextStyles.body.copyWith(fontStyle: FontStyle.italic),
        code: AppTextStyles.mono.copyWith(
          backgroundColor: AppColors.sqlChip,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.sqlChip,
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: AppTextStyles.body,
      ),
    );
  }
}

// ── SQL disclosure panel ──────────────────────────────────────────────────────

class _SqlDisclosure extends StatelessWidget {
  final String sql;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SqlDisclosure({
    required this.sql,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle row
        InkWell(
          onTap: onToggle,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.code_rounded,
                  size: 14,
                  color: AppColors.sqlText,
                ),
                const SizedBox(width: 6),
                Text(
                  'View SQL',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.sqlText,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),

        // SQL content
        if (isExpanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sqlChip,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.sqlText.withOpacity(0.15),
              ),
            ),
            child: Stack(
              children: [
                SelectableText(sql, style: AppTextStyles.mono),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: sql));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'SQL copied',
                            style: AppTextStyles.bodySecondary,
                          ),
                          backgroundColor: AppColors.surfaceCard,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
