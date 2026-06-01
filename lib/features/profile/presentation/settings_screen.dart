import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _dailyReminders = true;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Notifications'),
          _ToggleItem(
            label: 'Push Notifications',
            subtitle: 'Get test reminders and updates',
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          _ToggleItem(
            label: 'Daily Reminders',
            subtitle: 'Remind me to study every day',
            value: _dailyReminders,
            onChanged: (v) => setState(() => _dailyReminders = v),
          ),
          const SizedBox(height: 16),
          _SectionHeader('General'),
          _TapItem(label: 'Language', value: 'English', onTap: () {}),
          _TapItem(label: 'Data & Privacy', onTap: () {}),
          _TapItem(label: 'Terms of Service', onTap: () {}),
          const SizedBox(height: 16),
          _SectionHeader('Account'),
          _TapItem(label: 'Change Password', onTap: () {}),
          _TapItem(
            label: 'Delete Account',
            textColor: AppColors.error,
            onTap: () {},
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
    child: Text(title, style: AppTypography.heading3.copyWith(color: AppColors.textLight)),
  );
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.label, this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
    child: SwitchListTile(
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
  final String label;
  final String? value;
  final Color? textColor;
  final VoidCallback? onTap;
  const _TapItem({required this.label, this.value, this.textColor, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      title: Text(label, style: AppTypography.bodyLarge.copyWith(color: textColor)),
      trailing: value != null
          ? Text(value!, style: AppTypography.bodyMedium)
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
