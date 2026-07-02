import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/db_schema_model.dart';
import '../app_state.dart';
import '../app_theme.dart';

class EmptyChat extends StatelessWidget {
  final DatabaseSchema schema;

  const EmptyChat({super.key, required this.schema});

  // Suggested questions — these are grounded in the agri schema.
  // When swapping schema, update these to match the new domain.
  static const _suggestions = [
    'How many farmers are registered?',
    'Which crop was sown the most?',
    'List all harvests in 2024',
    'Which farmer harvested the most kg?',
    'What varieties of Paddy are recorded?',
    'Show total quantity sown per crop',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accentDim),
              ),
              child: const Icon(
                Icons.grain_rounded,
                color: AppColors.accent,
                size: 32,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'Ask about ${schema.databaseName}',
              style: AppTextStyles.heading,
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              '${schema.databaseDescription.split('.').first}.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 36),

          Text(
            'TRY ASKING',
            style: AppTextStyles.label,
          ),

          const SizedBox(height: 12),

          // ── Suggestion chips ──────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => _SuggestionChip(text: s))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textMuted.withOpacity(0.25),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySecondary.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
