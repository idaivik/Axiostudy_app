import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';

/// Exam-target selection — the first gate after account creation. The choice is
/// saved to `profiles.exam_type` before the user can proceed to the paywall.
class ExamSelectionScreen extends ConsumerStatefulWidget {
  const ExamSelectionScreen({super.key});

  @override
  ConsumerState<ExamSelectionScreen> createState() =>
      _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends ConsumerState<ExamSelectionScreen> {
  ExamType? _selected;
  bool _isSaving = false;
  String? _error;

  Future<void> _continue() async {
    final exam = _selected;
    if (exam == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) throw Exception('No signed-in user');
      await ref.read(authRepositoryProvider).setExamType(user.id, exam);
      ref.invalidate(currentUserProvider);
      if (mounted) context.go('/paywall');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your choice. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text('What are you preparing for?',
                  style: AppTypography.heading1),
              const SizedBox(height: 8),
              Text(
                'We\'ll tailor your subjects, tests, and AI coaching to your target exam.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 28),
              _ExamCard(
                exam: ExamType.jee,
                icon: LucideIcons.atom,
                gradient: AppColors.physicsGradient,
                selected: _selected == ExamType.jee,
                onTap: () => setState(() => _selected = ExamType.jee),
              ),
              const SizedBox(height: 16),
              _ExamCard(
                exam: ExamType.neet,
                icon: LucideIcons.stethoscope,
                gradient: AppColors.biologyGradient,
                selected: _selected == ExamType.neet,
                onTap: () => setState(() => _selected = ExamType.neet),
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.wrong),
                ),
                const SizedBox(height: 12),
              ],
              AxioButton(
                label: 'Continue',
                isLoading: _isSaving,
                onPressed: _selected == null ? null : _continue,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamType exam;
  final IconData icon;
  final LinearGradient gradient;
  final bool selected;
  final VoidCallback onTap;

  const _ExamCard({
    required this.exam,
    required this.icon,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.slate900.withValues(alpha: 0.04),
              blurRadius: selected ? 22 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.label, style: AppTypography.heading2),
                  const SizedBox(height: 4),
                  Text(exam.tagline, style: AppTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(LucideIcons.checkCircle2,
                  color: AppColors.primary, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
