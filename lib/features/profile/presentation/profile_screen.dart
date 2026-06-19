import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/billing/revenuecat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';
import '../../subscription/data/subscription_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    if (user == null) {
      return _Shell(
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return _Shell(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            children: [
              // ─── Header row: back affordance + title ───
              AnimatedEntrance(
                offsetX: -0.15,
                offsetY: 0,
                child: Row(
                  children: [
                    PressableScale(
                      scale: 0.85,
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          LucideIcons.arrowLeft,
                          size: 20,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Profile', style: AppTypography.heading2),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Avatar + identity
              AnimatedEntrance(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: AppTypography.heading2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 6),
                        PressableScale(
                          scale: 0.85,
                          onTap: () =>
                              _showEditNameDialog(context, user.id, user.name),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              LucideIcons.pencil,
                              size: 16,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Stats card
              AnimatedEntrance(
                delay: const Duration(milliseconds: 160),
                child: Container(
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
                      Container(width: 1, height: 36, color: AppColors.surfaceDark),
                      _Stat(label: 'Avg Score', value: '${user.averageScore.round()}%'),
                      Container(width: 1, height: 36, color: AppColors.surfaceDark),
                      _Stat(label: 'Streak', value: '${user.currentStreak}'),
                      Container(width: 1, height: 36, color: AppColors.surfaceDark),
                      _Stat(label: 'Mastered', value: '${user.topicsMastered}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Menu items — single location for everything
              AnimatedEntrance(
                delay: const Duration(milliseconds: 220),
                child: _MenuItem(
                  icon: LucideIcons.creditCard,
                  label: 'Manage Subscription',
                  sub: user.subscriptionTier.price,
                  onTap: () => _openSubscriptionSheet(context),
                ),
              ),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 270),
                child: _MenuItem(
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  onTap: () => context.go('/settings'),
                ),
              ),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 320),
                child: _MenuItem(
                  icon: LucideIcons.helpCircle,
                  label: 'Help & Support',
                  onTap: () => _showInfoDialog(
                    context,
                    'Help & Support',
                    'Need help? Reach out to us:\n\nEmail: support@axiostudy.com\nResponse time: Within 24 hours\n\nFAQ and knowledge base coming soon.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 380),
                child: SizedBox(
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
                              onPressed: () async {
                                Navigator.pop(ctx);
                                ref.read(guestModeProvider.notifier).state = false;
                                await ref.read(authRepositoryProvider).signOut();
                                if (context.mounted) context.go('/login');
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
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _openSubscriptionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SubscriptionSheet(),
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    String userId,
    String currentName,
  ) {
    showDialog(
      context: context,
      builder: (_) =>
          _EditNameDialog(userId: userId, currentName: currentName),
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

/// Dialog for editing the user's display name. Persists only the name column
/// and refreshes [currentUserProvider] so the profile updates in place.
class _EditNameDialog extends ConsumerStatefulWidget {
  final String userId;
  final String currentName;

  const _EditNameDialog({required this.userId, required this.currentName});

  @override
  ConsumerState<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<_EditNameDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name can\'t be empty.');
      return;
    }
    if (name == widget.currentName.trim()) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateName(widget.userId, name);
      ref.invalidate(currentUserProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn\'t update your name. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'Your name',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Wraps the profile content so it fills the screen on phones but docks as a
/// slim, tap-to-dismiss side panel on tablets (the route slides it in from the
/// left, so a full-width sheet would otherwise look out of place).
class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isTablet(context)) {
      return GradientBackground(child: child);
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 420,
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(6, 0),
                ),
              ],
            ),
            child: child,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
            ),
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

/// Bottom sheet that surfaces the live subscription state and the two store
/// actions Apple/Google require to be reachable outside the paywall: **Restore
/// purchases** and **Manage subscription** (opens the native management URL, or
/// the platform's generic subscriptions page as a fallback).
class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet();

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final tier = user?.subscriptionTier ?? SubscriptionTier.free;
    final status = user?.subscriptionStatus ?? SubscriptionStatus.none;
    final renews = user?.subscriptionExpiry ?? user?.trialEndsAt;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Subscription', style: AppTypography.heading2),
          const SizedBox(height: 16),
          _row('Plan', '${tier.label} · ${tier.price}'),
          _row('Status', status.label),
          if (renews != null)
            _row(
              status == SubscriptionStatus.trialing ? 'Trial ends' : 'Renews',
              _formatDate(renews),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _restoring ? null : _restore,
              icon: _restoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(_restoring ? 'Restoring…' : 'Restore purchases'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openManagement,
              icon: const Icon(LucideIcons.externalLink, size: 18),
              label: const Text('Manage subscription'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cancellations and refunds are handled by the App Store / Play Store.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMedium),
            Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final result = await ref.read(subscriptionControllerProvider).restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    // Pull the (possibly) updated entitlement back into the UI.
    ref.invalidate(currentUserProvider);
    final msg = result.success
        ? 'Subscription restored.'
        : (result.errorMessage ?? 'No purchases found to restore.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.success ? AppColors.primary : AppColors.error,
      ),
    );
  }

  Future<void> _openManagement() async {
    final managed = await RevenueCat.managementUrl();
    final fallback = (Platform.isIOS || Platform.isMacOS)
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    if (!mounted) return;
    final ok = await launchUrl(
      Uri.parse(managed ?? fallback),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open subscription settings.')),
      );
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = d.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
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
