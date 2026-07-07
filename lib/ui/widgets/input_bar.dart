import 'package:flutter/material.dart';

import '../app_theme.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isProcessing;
  final void Function(String) onSend;

  const InputBar({
    super.key,
    required this.controller,
    required this.isProcessing,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.textMuted.withOpacity(0.15),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text field ───────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isProcessing,
              style: AppTextStyles.body,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isProcessing
                    ? 'Thinking…'
                    : '',
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              onSubmitted: isProcessing ? null : onSend,
            ),
          ),

          const SizedBox(width: 10),

          // ── Send button ──────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isProcessing
                ? const _ProcessingButton(key: ValueKey('proc'))
                : _SendButton(
                    key: const ValueKey('send'),
                    onTap: () => onSend(controller.text),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.black,
          size: 20,
        ),
      ),
    );
  }
}

class _ProcessingButton extends StatelessWidget {
  const _ProcessingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.accent),
        ),
      ),
    );
  }
}
