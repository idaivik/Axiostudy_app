import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/axio_button.dart';
import '../../auth/data/auth_providers.dart';

/// AI profiling — the final onboarding gate. Trial is active at this point;
/// collecting a couple of quick signals lets the AI tailor the first plan.
/// Completing it flips `onboarding_completed` and "officially enters the app".
class ProfilingScreen extends ConsumerStatefulWidget {
  const ProfilingScreen({super.key});

  @override
  ConsumerState<ProfilingScreen> createState() => _ProfilingScreenState();
}

class _ProfilingScreenState extends ConsumerState<ProfilingScreen> {
  static const _grades = ['Class 11', 'Class 12', 'Dropper'];
  static const _goals = [
    (LucideIcons.target, 'Top rank', 'Aiming for a top-tier rank'),
    (LucideIcons.trendingUp, 'Strong score', 'A solid, competitive score'),
    (LucideIcons.bookOpen, 'Build basics', 'Strengthen my fundamentals'),
  ];

  String? _grade;
  int? _goalIndex;
  bool _isSaving = false;
  String? _error;

  bool get _canFinish => _grade != null && _goalIndex != null;

  Future<void> _finish() async {
    if (!_canFinish) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) throw Exception('No signed-in user');
      await ref
          .read(authRepositoryProvider)
          .completeOnboarding(user.id, grade: _grade);
      ref.invalidate(currentUserProvider);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not finish setup. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final examLabel = ref
            .watch(currentUserProvider)
            .valueOrNull
            ?.examType
            ?.label ??
        'your exam';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.greenSurface,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.checkCircle2,
                              size: 14, color: AppColors.greenStrong),
                          const SizedBox(width: 6),
                          Text(
                            'TRIAL ACTIVE',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.greenStrong),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text("Let's personalize your prep",
                        style: AppTypography.heading1),
                    const SizedBox(height: 8),
                    Text(
                      'A couple of quick questions so the AI can tailor your '
                      '$examLabel plan.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 28),

                    Text('Where are you in your prep?',
                        style: AppTypography.heading3),
                    const SizedBox(height: 12),
                    Row(
                      children: _grades.map((g) {
                        final selected = _grade == g;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: g == _grades.last ? 0 : 10),
                            child: _ChoiceChip(
                              label: g,
                              selected: selected,
                              onTap: () => setState(() => _grade = g),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),
                    Text("What's your goal?", style: AppTypography.heading3),
                    const SizedBox(height: 12),
                    ...List.generate(_goals.length, (i) {
                      final (icon, title, subtitle) = _goals[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _GoalCard(
                          icon: icon,
                          title: title,
                          subtitle: subtitle,
                          selected: _goalIndex == i,
                          onTap: () => setState(() => _goalIndex = i),
                        ),
                      );
                    }),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.wrong),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: AxioButton(
                label: 'Enter AxioStudy',
                icon: LucideIcons.arrowRight,
                isLoading: _isSaving,
                onPressed: _canFinish ? _finish : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: selected ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.greenSurface
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMedium),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.heading3),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (selected)
              Icon(LucideIcons.checkCircle2,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
