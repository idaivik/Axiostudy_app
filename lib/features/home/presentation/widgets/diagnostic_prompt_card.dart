import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_providers.dart';

/// Session-level dismiss state — resets on app restart so the banner
/// reappears as a gentle reminder until the user actually takes the test.
final diagnosticBannerDismissedProvider = StateProvider<bool>((ref) => false);

class DiagnosticPromptCard extends ConsumerWidget {
  const DiagnosticPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTaken = ref.watch(hasTakenDiagnosticProvider);
    final dismissed = ref.watch(diagnosticBannerDismissedProvider);

    if (hasTaken || dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.clipboardCheck,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          // Text + actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnostic Test Pending',
                  style: AppTypography.heading3.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'Complete it to unlock personalized AI study insights.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMedium,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/test-selection'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Take Test',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(diagnosticBannerDismissedProvider.notifier)
                            .state = true;
                      },
                      child: Text(
                        'Dismiss',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
