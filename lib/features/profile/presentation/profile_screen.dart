import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/data/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(24)),
              child: Center(child: Text(user.name.substring(0, 1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 14),
            Text(user.name, style: AppTypography.heading2),
            Text(user.email, style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
              child: Text(user.subscriptionTier.label, style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))]),
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
            _MenuItem(icon: Icons.credit_card_rounded, label: 'Manage Subscription', sub: 'Opens axiostudy.com', onTap: () {}),
            _MenuItem(icon: Icons.settings_rounded, label: 'Settings', onTap: () => context.push('/settings')),
            _MenuItem(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () {}),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { ref.read(authStateProvider.notifier).state = false; context.go('/login'); },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: AppTypography.heading3), const SizedBox(height: 2), Text(label, style: AppTypography.caption)]);
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
    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.textMedium, size: 20)),
    title: Text(label, style: AppTypography.bodyLarge),
    subtitle: sub != null ? Text(sub!, style: AppTypography.caption) : null,
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
