import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/data/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  user.name.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(user.name, style: AppTypography.heading2),
            Text(user.email, style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.subscriptionTier.label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Stats card
            Container(
              padding: const EdgeInsets.all(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: 'Tests', value: '${user.testsCompleted}'),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  _Stat(label: 'Avg Score', value: '${user.averageScore.round()}%'),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  _Stat(label: 'Streak', value: '${user.currentStreak}'),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  _Stat(label: 'Mastered', value: '${user.topicsMastered}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Menu items — single location for everything
            _MenuItem(
              icon: LucideIcons.creditCard,
              label: 'Manage Subscription',
              sub: user.subscriptionTier.price,
              onTap: () => _showInfoDialog(
                context,
                'Manage Subscription',
                'Your current plan: ${user.subscriptionTier.label}\n\nSubscription management will be available at axiostudy.com in a future update.',
              ),
            ),
            _MenuItem(
              icon: LucideIcons.barChart3,
              label: 'Detailed Analytics',
              onTap: () => context.push('/analytics'),
            ),
            _MenuItem(
              icon: LucideIcons.settings,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
            _MenuItem(
              icon: LucideIcons.helpCircle,
              label: 'Help & Support',
              onTap: () => _showInfoDialog(
                context,
                'Help & Support',
                'Need help? Reach out to us:\n\nEmail: support@axiostudy.com\nResponse time: Within 24 hours\n\nFAQ and knowledge base coming soon.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final repo = ref.read(authRepositoryProvider);
                            repo.signOut();
                            context.go('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          child: const Text('Logout', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(LucideIcons.logOut),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: AppTypography.heading3),
      const SizedBox(height: 2),
      Text(label, style: AppTypography.caption),
    ],
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  const _MenuItem({required this.icon, required this.label, this.sub, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.textMedium, size: 20),
    ),
    title: Text(label, style: AppTypography.bodyLarge),
    subtitle: sub != null ? Text(sub!, style: AppTypography.caption) : null,
    trailing: Icon(LucideIcons.chevronRight, color: AppColors.textLight, size: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
