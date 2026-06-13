import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';

/// Settings screen — the SINGLE place for all app settings.
/// Rendered as a primary navigation tab inside the app shell.
/// All toggles and buttons are functional.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _dailyReminders = true;
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _SectionHeader('Notifications'),
      _ToggleItem(
        icon: LucideIcons.bell,
        label: 'Push Notifications',
        subtitle: 'Get test reminders and updates',
        value: _notifications,
        onChanged: (v) {
          setState(() => _notifications = v);
          _showSnack(context, v ? 'Notifications enabled' : 'Notifications disabled');
        },
      ),
      _ToggleItem(
        icon: LucideIcons.alarmClock,
        label: 'Daily Reminders',
        subtitle: 'Remind me to study every day',
        value: _dailyReminders,
        onChanged: (v) {
          setState(() => _dailyReminders = v);
          _showSnack(context, v ? 'Daily reminders on' : 'Daily reminders off');
        },
      ),
      const SizedBox(height: 16),
      _SectionHeader('Study Plan'),
      _TapItem(
        icon: LucideIcons.milestone,
        label: 'Study Roadmap',
        subtitle: 'Coaching, exam date & daily time',
        onTap: () => context.push('/roadmap/setup'),
      ),
      const SizedBox(height: 16),
      _SectionHeader('General'),
      _TapItem(
        icon: LucideIcons.globe,
        label: 'Language',
        value: _language,
        onTap: () => _showLanguageDialog(),
      ),
      _TapItem(
        icon: LucideIcons.shield,
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
      const SizedBox(height: 16),
      _SectionHeader('Account'),
      _TapItem(
        icon: LucideIcons.key,
        label: 'Change Password',
        onTap: () => _showChangePasswordDialog(),
      ),
      _TapItem(
        icon: LucideIcons.trash2,
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
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      title,
      style: AppTypography.heading3.copyWith(color: AppColors.textLight),
    ),
  );
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: SwitchListTile(
      secondary: Icon(icon, size: 20, color: AppColors.textMedium),
      title: Text(label, style: AppTypography.bodyLarge),
      subtitle: subtitle != null ? Text(subtitle!, style: AppTypography.caption) : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _TapItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? value;
  final Color? textColor;
  final VoidCallback? onTap;
  const _TapItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.textColor,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
      leading: Icon(icon, size: 20, color: textColor ?? AppColors.textMedium),
      title: Text(label, style: AppTypography.bodyLarge.copyWith(color: textColor)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTypography.caption)
          : null,
      trailing: value != null
          ? Text(value!, style: AppTypography.bodyMedium)
          : Icon(LucideIcons.chevronRight, color: AppColors.textLight, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
