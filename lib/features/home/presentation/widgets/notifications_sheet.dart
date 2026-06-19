import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/data/auth_providers.dart';

Future<void> showNotificationsSheet(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss notifications',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, a, b) => const _NotificationsPanel(),
    transitionBuilder: (context, animation, _, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}

class _NotificationsPanel extends ConsumerWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTakenDiagnostic = ref.watch(hasTakenDiagnosticProvider);
    final size = MediaQuery.of(context).size;
    final isTablet = Responsive.isTablet(context);

    // Phone: full-height sheet hugging the right edge. Tablet: a compact,
    // floating card inset from the top-right corner so it doesn't span the
    // whole screen horizontally or vertically.
    final width = isTablet ? 380.0 : size.width * 0.84;

    final panel = Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: isTablet ? null : double.infinity,
        constraints: isTablet
            ? BoxConstraints(maxHeight: size.height * 0.7)
            : const BoxConstraints(),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: isTablet
              ? BorderRadius.circular(24)
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(-6, 0),
            ),
          ],
        ),
        child: SafeArea(
          // The tablet card already floats with its own margins, so it doesn't
          // need to dodge the system insets.
          top: !isTablet,
          bottom: !isTablet,
          child: Column(
            mainAxisSize: isTablet ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Notifications', style: AppTypography.heading2),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      color: AppColors.textMedium,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              if (!hasTakenDiagnostic)
                _NotificationTile(
                  icon: LucideIcons.clipboardCheck,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.greenSurface,
                  title: 'Diagnostic Test Pending',
                  subtitle:
                      'Complete it to unlock personalized AI study insights.',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/test-selection');
                  },
                )
              else
                const _EmptyState(),
            ],
          ),
        ),
      ),
    );

    if (!isTablet) {
      return Align(alignment: Alignment.centerRight, child: panel);
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: panel,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.heading3.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMedium,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.bellOff, size: 32, color: AppColors.textLight),
            const SizedBox(height: 10),
            Text(
              'No notifications',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
