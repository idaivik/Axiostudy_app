import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../analytics/data/analytics_providers.dart';
import '../data/test_providers.dart';

/// Detail screen for a mock test the student has already finished.
///
/// Reached by tapping a card in the "Completed" section of the Mock Tests tab.
/// Shows the most recent attempt's headline stats and offers two actions:
///   • View Full Analysis → the Analytics screen (Past Attempted Tests widget)
///   • Reattempt          → starts a fresh attempt of the same test
class CompletedTestScreen extends ConsumerWidget {
  final String testId;
  const CompletedTestScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(testNamesProvider).valueOrNull ?? const {};
    final lastByTest = ref.watch(lastAttemptByTestProvider).valueOrNull ?? const {};
    final attempt = lastByTest[testId];
    final testName = names[testId] ?? 'Mock Test';

    return GradientBackground(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Completed Test'),
      ),
      child: attempt == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No attempt found for this test yet.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _CompletedBody(
              testId: testId,
              testName: testName,
              attemptId: attempt.id,
              scorePercentage: attempt.scorePercentage,
              completedAt: attempt.endTime ?? attempt.startTime,
            ),
    );
  }
}

class _CompletedBody extends ConsumerWidget {
  final String testId;
  final String testName;
  final String attemptId;
  final double scorePercentage;
  final DateTime completedAt;

  const _CompletedBody({
    required this.testId,
    required this.testName,
    required this.attemptId,
    required this.scorePercentage,
    required this.completedAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rich per-attempt stats (accuracy, time). Best-effort — may be null for
    // very old attempts; the score ring below always renders regardless.
    final analytics = ref.watch(attemptAnalyticsProvider(attemptId)).valueOrNull;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(testName, style: AppTypography.heading2, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'Last attempt · ${_fmtDate(completedAt)}',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Score ring
          Center(
            child: ProgressCircle(
              progress: (scorePercentage / 100).clamp(0.0, 1.0),
              size: 150,
              strokeWidth: 12,
              progressColor: _scoreColor(scorePercentage),
              centerWidget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${scorePercentage.round()}%',
                      style: AppTypography.heading1),
                  Text('Score', style: AppTypography.caption),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stat chips (accuracy / correct / time) — only when analytics exist.
          if (analytics != null)
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.target,
                    label: 'Accuracy',
                    value: '${(analytics.accuracy * 100).round()}%',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.checkCircle2,
                    label: 'Correct',
                    value:
                        '${analytics.totalCorrect}/${analytics.totalCorrect + analytics.totalWrong + analytics.totalUnanswered}',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.clock,
                    label: 'Time',
                    value: _fmtDuration(analytics.totalTimeSeconds),
                    color: AppColors.mathematics,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 28),

          // Primary action — full analysis.
          ElevatedButton.icon(
            onPressed: () => context.go('/analytics'),
            icon: const Icon(LucideIcons.barChart3, size: 18),
            label: const Text('View Full Analysis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary action — reattempt (starts a fresh attempt).
          OutlinedButton.icon(
            onPressed: () => context.push('/test/$testId'),
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
            label: const Text('Reattempt'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double pct) {
    if (pct >= 70) return AppColors.success;
    if (pct >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading3),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

String _fmtDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '${s}s';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
