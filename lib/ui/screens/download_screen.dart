import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDownloading = state.status == AppStatus.downloading;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),

              // ── Logo mark ───────────────────────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentDim, width: 1),
                ),
                child: const Icon(
                  Icons.grain_rounded,
                  color: AppColors.accent,
                  size: 28,
                ),
              ),

              const SizedBox(height: 40),

              // ── Heading ─────────────────────────────────────────────────
              Text('One-time setup', style: AppTextStyles.displayLarge),
              const SizedBox(height: 12),
              Text(
                'AskBase runs entirely on your device — no internet needed '
                'after setup. We need to download the AI model once.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 40),

              // ── Model info card ──────────────────────────────────────────
              const _InfoCard(
                rows: [
                  ('Model', 'Qwen2.5-Coder 1.5B (Q4_K_M)'),
                  ('Download size', '~986 MB'),
                  ('Stored in', 'App private storage'),
                  ('Internet after setup', 'Not required'),
                ],
              ),

              const SizedBox(height: 32),

              // ── WiFi warning ─────────────────────────────────────────────
              if (!isDownloading)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connect to WiFi before downloading to avoid '
                          'mobile data charges.',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (isDownloading) ...[
                // ── Progress ───────────────────────────────────────────────
                Text(
                  'Downloading…  ${state.downloadedMB} MB / ${state.totalMB} MB',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.downloadProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceCard,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(state.downloadProgress * 100).toStringAsFixed(1)}%',
                  style: AppTextStyles.caption,
                ),
              ],

              if (state.errorMessage != null && !isDownloading) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],

              const Spacer(),

              // ── Action button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: isDownloading
                    ? OutlinedButton(
                        onPressed: () =>
                            context.read<AppState>().cancelDownload(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel download',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.error),
                        ),
                      )
                    : FilledButton(
                        onPressed: () =>
                            context.read<AppState>().startDownload(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Download model',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.2)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(row.$1, style: AppTextStyles.bodySecondary),
                    const Spacer(),
                    Text(
                      row.$2,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.textMuted.withOpacity(0.15),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
