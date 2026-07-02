import 'package:askbase/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/input_bar.dart';
import '../widgets/empty_chat.dart';
import '../widgets/thinking_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    context.read<AppState>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Auto-scroll when messages change
    if (state.messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context, state),
      body: Column(
        children: [
          // ── Message list ───────────────────────────────────────────────
          Expanded(
            child: state.messages.isEmpty
                ? EmptyChat(schema: state.schema)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final msg = state.messages[index];
                      if (msg.isAssistant &&
                          msg.state == MessageState.thinking) {
                        return const ThinkingIndicator();
                      }
                      return ChatBubble(message: msg);
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────────────
          InputBar(
            controller: _inputController,
            isProcessing: state.isProcessing,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppState state) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentDim),
            ),
            child: const Icon(
              Icons.grain_rounded,
              color: AppColors.accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.schema.databaseName,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (state.messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Clear chat',
            onPressed: () => _confirmClear(context, state),
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: AppColors.textMuted.withOpacity(0.15),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clear conversation?', style: AppTextStyles.heading),
            const SizedBox(height: 8),
            Text(
              'All messages will be removed. The database and model stay intact.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(
                          color: AppColors.textMuted.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Keep'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      state.clearChat();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error.withOpacity(0.15),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
