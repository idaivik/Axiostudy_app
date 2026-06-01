import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';

/// Test type selection screen after user chooses to take diagnostic.
class TestSelectionScreen extends StatelessWidget {
  const TestSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choose Your Test'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select test type', style: AppTypography.heading2),
              const SizedBox(height: 8),
              Text(
                'Pick the format that works best for you',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 28),
              // Combined test
              _TestOptionCard(
                title: 'Combined JEE Test',
                description: 'Physics + Chemistry + Maths\n90 questions  •  3 hours',
                icon: LucideIcons.sparkles,
                gradient: AppColors.primaryGradient,
                isRecommended: true,
                onTap: () => context.push('/test/test_diag_001'),
              ),
              const SizedBox(height: 16),
              Text('Or take individual tests:', style: AppTypography.bodyMedium),
              const SizedBox(height: 12),
              // Individual tests
              _TestOptionCard(
                title: 'Physics',
                description: '30 questions  •  1 hour',
                icon: SubjectType.physics.iconData,
                gradient: AppColors.physicsGradient,
                onTap: () => context.push('/test/test_diag_001'),
              ),
              const SizedBox(height: 10),
              _TestOptionCard(
                title: 'Chemistry',
                description: '30 questions  •  1 hour',
                icon: SubjectType.chemistry.iconData,
                gradient: AppColors.chemistryGradient,
                onTap: () => context.push('/test/test_diag_001'),
              ),
              const SizedBox(height: 10),
              _TestOptionCard(
                title: 'Mathematics',
                description: '30 questions  •  1 hour',
                icon: SubjectType.mathematics.iconData,
                gradient: AppColors.mathematicsGradient,
                onTap: () => context.push('/test/test_diag_001'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final LinearGradient gradient;
  final bool isRecommended;
  final VoidCallback? onTap;

  const _TestOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    this.isRecommended = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.heading3),
                  const SizedBox(height: 2),
                  Text(description, style: AppTypography.caption),
                ],
              ),
            ),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.star, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Best',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}
