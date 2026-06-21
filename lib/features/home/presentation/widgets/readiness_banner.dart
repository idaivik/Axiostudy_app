import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

import '../../../subjects/data/subjects_providers.dart';
import '../../../auth/data/auth_providers.dart';

class ReadinessBanner extends ConsumerStatefulWidget {
  const ReadinessBanner({super.key});

  @override
  ConsumerState<ReadinessBanner> createState() => _ReadinessBannerState();
}

class _ReadinessBannerState extends ConsumerState<ReadinessBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? [];
    final readiness = subjects.isEmpty
        ? 0.0
        : subjects.map((s) => s.completionPercentage).reduce((a, b) => a + b) / subjects.length;

    final examDate = DateTime(2027, 1, 28);
    final daysRemaining = examDate.difference(DateTime.now()).inDays;
    final user = ref.watch(currentUserProvider).valueOrNull;

    // Demoted to a slim light strip (Plan B): the Overview AI coach is now the
    // only hero-gradient surface, so readiness reads as a quiet status line.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
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
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.target, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JEE Readiness',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$daysRemaining days to exam  •  ${user?.testsCompleted ?? 0} tests taken',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, child) => Text(
                  '${(readiness * 100 * _progressAnim.value).round()}%',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.primary,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (context, child) => LinearProgressIndicator(
                value: readiness * _progressAnim.value,
                minHeight: 6,
                backgroundColor: AppColors.surfaceDark,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
