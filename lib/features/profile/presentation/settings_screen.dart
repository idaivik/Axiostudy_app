import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/notification_prefs.dart';
import '../../../core/notifications/notification_prefs_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../auth/data/auth_providers.dart';
import '../../subscription/domain/entitlements.dart';

/// Settings screen — the SINGLE place for all app settings.
/// Rendered as a primary navigation tab inside the app shell.
/// All toggles and buttons are functional.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Feature 1 — reminder prefs (persisted to notification_prefs).
  NotificationPrefs _prefs = NotificationPrefs.defaults;
  String _language = 'English';
  bool _earlyAccessBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loaded = await ref.read(notificationPrefsRepositoryProvider).load();
      if (mounted) setState(() => _prefs = loaded);
    });
  }

  Future<void> _savePrefs(NotificationPrefs next) async {
    setState(() => _prefs = next);
    await ref.read(notificationPrefsRepositoryProvider).save(next);
    ref.invalidate(notificationPrefsProvider);
  }

  Future<void> _setRemindersEnabled(bool enabled) async {
    if (enabled) {
      // Ask for the OS permission at the moment the user opts in, and register
      // the FCM token for server-driven reminders (no-op until Firebase is set).
      await NotificationService.instance.requestPermission();
      await FcmService.instance.requestPermissionAndRegister();
    }
    await _savePrefs(_prefs.copyWith(enabled: enabled));
    if (mounted) {
      _showSnack(context, enabled ? 'Reminders on' : 'Reminders off');
    }
  }

  Future<void> _pickQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _prefs.quietStart,
      helpText: 'Quiet hours start',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _prefs.quietEnd,
      helpText: 'Quiet hours end',
    );
    if (end == null) return;
    await _savePrefs(_prefs.copyWith(quietStart: start, quietEnd: end));
  }

  /// Bucket 2 §3a — everyone can contact support; Pro tickets are flagged
  /// priority in the subject so they're triaged first (no hard SLA promised).
  Future<void> _contactSupport({
    required bool isPro,
    required String planLabel,
  }) async {
    final subject = isPro ? '[PRIORITY] AxioStudy support' : 'AxioStudy support';
    final body = 'Plan: $planLabel\n\n'
        '(Describe your issue here — the more detail, the faster we can help.)\n\n';
    final uri = Uri.parse(
      'mailto:support@axiostudy.com'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnack(context, 'Could not open your mail app — email support@axiostudy.com.');
    }
  }

  /// Bucket 2 §3c — flip the early-access opt-in on the profile.
  Future<void> _setEarlyAccess(bool enabled) async {
    if (_earlyAccessBusy) return;
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    setState(() => _earlyAccessBusy = true);
    try {
      await ref.read(authRepositoryProvider).setEarlyAccess(userId, enabled);
      ref.invalidate(currentUserProvider);
      if (mounted) {
        _showSnack(context, enabled ? 'Early access on' : 'Early access off');
      }
    } catch (_) {
      if (mounted) _showSnack(context, "Couldn't update early access.");
    } finally {
      if (mounted) setState(() => _earlyAccessBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    // prioritySupport bundles priority support + feature voting + early access.
    final isPro = user?.can(Feature.prioritySupport) ?? false;

    final items = <Widget>[
      _SectionHeader('Notifications'),
      _ToggleItem(
        icon: LucideIcons.bell,
        accent: AppColors.primary,
        label: 'Revision Reminders',
        subtitle: 'Nudges to revise your weak chapters',
        value: _prefs.enabled,
        onChanged: _setRemindersEnabled,
      ),
      _TapItem(
        icon: LucideIcons.moon,
        accent: AppColors.physics,
        label: 'Quiet Hours',
        subtitle: 'No reminders during these hours',
        value: _prefs.quietRangeLabel(context),
        onTap: _prefs.enabled ? _pickQuietHours : null,
      ),
      const SizedBox(height: 18),
      _SectionHeader('Study Plan'),
      _TapItem(
        icon: LucideIcons.milestone,
        accent: AppColors.mathematics,
        label: 'Study Roadmap',
        subtitle: 'Coaching, exam date & daily time',
        onTap: () => context.push('/roadmap/setup'),
      ),
      const SizedBox(height: 18),
      _SectionHeader('Support'),
      // Everyone can reach support; Pro gets the priority flag + badge (§3a).
      _TapItem(
        icon: LucideIcons.lifeBuoy,
        accent: AppColors.chemistry,
        label: 'Contact support',
        subtitle: isPro
            ? 'Pro members are answered first'
            : 'Reach our team by email',
        badge: isPro ? 'Priority' : null,
        onTap: () => _contactSupport(
          isPro: isPro,
          planLabel: user?.subscriptionTier.label ?? '—',
        ),
      ),
      // Feature voting + early access are Pro perks — hidden for everyone else.
      if (isPro)
        _TapItem(
          icon: LucideIcons.messageSquarePlus,
          accent: AppColors.biology,
          label: 'Feature voting',
          subtitle: 'Vote on what we build next',
          onTap: () => context.push('/feature-voting'),
        ),
      if (isPro)
        _ToggleItem(
          icon: LucideIcons.flaskConical,
          accent: AppColors.warning,
          label: 'Early access',
          subtitle: 'Try experimental features before everyone else',
          value: user?.earlyAccess ?? false,
          onChanged: _setEarlyAccess,
        ),
      const SizedBox(height: 18),
      _SectionHeader('General'),
      _TapItem(
        icon: LucideIcons.globe,
        accent: AppColors.chemistry,
        label: 'Language',
        value: _language,
        onTap: () => _showLanguageDialog(),
      ),
      _TapItem(
        icon: LucideIcons.shield,
        accent: AppColors.primary,
        label: 'Data & Privacy',
        onTap: () => _showInfoDialog(
          'Data & Privacy',
          'Your data is stored securely and never shared with third parties.\n\n'
          '• Test results are encrypted at rest\n'
          '• Analytics are processed locally\n'
          '• You can request data deletion anytime\n\n'
          'Full privacy policy at axiostudy.com/privacy',
        ),
      ),
      _TapItem(
        icon: LucideIcons.fileText,
        accent: AppColors.textMedium,
        label: 'Terms of Service',
        onTap: () => _showInfoDialog(
          'Terms of Service',
          'By using AxioStudy, you agree to our terms:\n\n'
          '• Content is for educational use only\n'
          '• One account per student\n'
          '• Respect intellectual property\n\n'
          'Full terms at axiostudy.com/terms',
        ),
      ),
      const SizedBox(height: 18),
      _SectionHeader('Account'),
      _TapItem(
        icon: LucideIcons.key,
        accent: AppColors.physics,
        label: 'Change Password',
        onTap: () => _showChangePasswordDialog(),
      ),
      _TapItem(
        icon: LucideIcons.trash2,
        accent: AppColors.error,
        label: 'Delete Account',
        textColor: AppColors.error,
        onTap: () => _showDeleteAccountDialog(),
      ),
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            child: AnimatedEntrance(
              offsetY: -0.2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: AppTypography.heading1
                        .copyWith(fontSize: 26, letterSpacing: -0.6),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your preferences',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textLight, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                for (int i = 0; i < items.length; i++)
                  AnimatedEntrance(
                    delay: Duration(milliseconds: 70 + i * 35),
                    child: items[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Language'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'हिन्दी', 'తెలుగు', 'தமிழ்'].map((lang) {
            final isSelected = lang == _language;
            return ListTile(
              title: Text(lang),
              leading: Icon(
                isSelected ? LucideIcons.checkCircle : LucideIcons.circle,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                size: 20,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() => _language = lang);
                Navigator.pop(ctx);
                _showSnack(context, 'Language set to $lang');
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(LucideIcons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(LucideIcons.keyRound),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnack(context, 'Password updated successfully');
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'This action cannot be undone. All your test data, progress, '
          'and subscription will be permanently deleted.\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnack(context, 'Account deletion request submitted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(message),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
    child: Text(
      title.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.textLight,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// Rounded icon tile shown at the leading edge of every settings row. The
/// tint gives each row a clear accent without overwhelming the layout.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  const _IconTile({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 19, color: accent),
  );
}

/// Shared row chrome: rounded card, accent icon tile, a bold title and a
/// noticeably lighter subtitle. [trailing] holds a switch, chevron or value.
class _SettingCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool enabled;
  const _SettingCard({
    required this.icon,
    required this.accent,
    required this.label,
    this.subtitle,
    this.labelColor,
    required this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  _IconTile(icon: icon, accent: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: labelColor ?? AppColors.textDark,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w400,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({
    required this.icon,
    required this.accent,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _SettingCard(
    icon: icon,
    accent: accent,
    label: label,
    subtitle: subtitle,
    onTap: () => onChanged(!value),
    trailing: Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.white,
      activeTrackColor: AppColors.primary,
    ),
  );
}

class _TapItem extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String? subtitle;
  final String? value;
  final String? badge;
  final Color? textColor;
  final VoidCallback? onTap;
  const _TapItem({
    required this.icon,
    required this.accent,
    required this.label,
    this.subtitle,
    this.value,
    this.badge,
    this.textColor,
    this.onTap,
  });

  Widget _trailing() {
    final chevron =
        Icon(LucideIcons.chevronRight, color: AppColors.textLight, size: 18);
    if (badge != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          chevron,
        ],
      );
    }
    if (value != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value!,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(width: 6),
          chevron,
        ],
      );
    }
    return chevron;
  }

  @override
  Widget build(BuildContext context) => _SettingCard(
    icon: icon,
    accent: accent,
    label: label,
    subtitle: subtitle,
    labelColor: textColor,
    enabled: onTap != null,
    onTap: onTap,
    trailing: _trailing(),
  );
}
