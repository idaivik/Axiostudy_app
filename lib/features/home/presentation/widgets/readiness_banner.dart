import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../subjects/data/subjects_providers.dart';
import '../../../auth/data/auth_providers.dart';

/// Top banner showing JEE/NEET readiness score with exam countdown.
/// Calculates readiness from actual subject completion data.
class ReadinessBanner extends ConsumerWidget {
  const ReadinessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calculate readiness from actual subject data
    final subjectsAsync = ref.watch(subjectsProvider);
    final subjects = subjectsAsync.valueOrNull ?? [];
    final readiness = subjects.isEmpty
        ? 0.0
        : subjects.map((s) => s.completionPercentage).reduce((a, b) => a + b) /
            subjects.length;

    // Exam date — JEE Main 2027 (example)
    final examDate = DateTime(2027, 1, 28);
    final daysRemaining = examDate.difference(DateTime.now()).inDays;

    final user = ref.watch(currentUserProvider).valueOrNull;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.target,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JEE Readiness',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$daysRemaining days remaining  •  ${user?.testsCompleted ?? 0} tests taken',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(readiness * 100).round()}%',
                style: AppTypography.numberMedium.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: readiness,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            readiness >= 0.7
                ? 'Great progress — you\'re ahead of schedule'
                : readiness >= 0.5
                    ? 'You\'re on track — keep up the consistency'
                    : 'Let\'s build momentum — follow today\'s plan',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
