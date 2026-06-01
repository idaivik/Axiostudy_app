import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/data/auth_providers.dart';

/// Tests tab — shows available mock tests, practice tests, and test history.
/// All cards are tappable and navigate to the appropriate screens.
class TestsListScreen extends ConsumerWidget {
  const TestsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tests', style: AppTypography.heading1),
                  const SizedBox(height: 4),
                  Text(
                    '${user?.testsCompleted ?? 0} tests completed  •  ${user?.averageScore.round() ?? 0}% avg score',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          // Quick test banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GestureDetector(
                onTap: () => context.push('/test-selection'),
                child: Container(
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Quick Test',
                              style: AppTypography.heading3
                                  .copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Focused on your areas that need practice',
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Upcoming tests
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Upcoming', style: AppTypography.heading2),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _TestCard(
                  title: 'JEE Full Mock Test #5',
                  subtitle: '90 questions  |  3 hours',
                  date: 'May 9, 2026',
                  icon: LucideIcons.fileText,
                  isHighlighted: true,
                  onTap: () => context.push('/test/test_diag_001'),
                ),
                _TestCard(
                  title: 'Physics Practice Test',
                  subtitle: '30 questions  |  1 hour',
                  date: 'May 12, 2026',
                  icon: LucideIcons.atom,
                  onTap: () => context.push('/test/test_diag_001'),
                ),
                _TestCard(
                  title: 'Chemistry Mock Test',
                  subtitle: '30 questions  |  1 hour',
                  date: 'May 15, 2026',
                  icon: LucideIcons.flaskConical,
                  onTap: () => context.push('/test/test_diag_001'),
                ),
              ]),
            ),
          ),
          // Past results
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Recent Results', style: AppTypography.heading2),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ResultCard(
                  title: 'JEE Mock Test #4',
                  score: 72.5,
                  date: 'May 5, 2026',
                  improvement: 7.5,
                  onTap: () => context.push('/results/attempt_001'),
                ),
                _ResultCard(
                  title: 'Physics Practice',
                  score: 65.0,
                  date: 'Apr 29, 2026',
                  improvement: 7.0,
                  onTap: () => context.push('/results/attempt_001'),
                ),
                _ResultCard(
                  title: 'JEE Mock Test #3',
                  score: 58.0,
                  date: 'Apr 22, 2026',
                  improvement: 10.0,
                  onTap: () => context.push('/results/attempt_001'),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final IconData icon;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _TestCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted ? AppColors.primarySurface : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: isHighlighted
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: isHighlighted ? AppColors.primary : AppColors.textMedium),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(date, style: AppTypography.caption),
                if (isHighlighted) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Next',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final double score;
  final String date;
  final double improvement;
  final VoidCallback? onTap;

  const _ResultCard({
    required this.title,
    required this.score,
    required this.date,
    required this.improvement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${score.round()}%',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(date, style: AppTypography.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.trendingUp, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '+${improvement.round()}%',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
