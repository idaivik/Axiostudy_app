import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/roadmap_providers.dart';
import '../data/roadmap_seed_data.dart';
import '../domain/roadmap_models.dart';

/// Setup flow that captures everything the planner needs: which coaching the
/// student is in (so the plan matches class order), where their class currently
/// is, the exam they're targeting + date, and how much time they have per day.
class RoadmapSetupScreen extends ConsumerStatefulWidget {
  const RoadmapSetupScreen({super.key});

  @override
  ConsumerState<RoadmapSetupScreen> createState() => _RoadmapSetupScreenState();
}

class _RoadmapSetupScreenState extends ConsumerState<RoadmapSetupScreen> {
  String _coachingId = 'allen';
  ExamType _examType = ExamType.jee;
  DateTime? _examDate;
  int _dailyMinutes = 120;
  int _currentPosition = 0;
  bool _saving = false;

  List<CoachingInstitute> get _institutes => RoadmapSeedData.institutes;

  SyllabusSequence get _sequence =>
      RoadmapSeedData.sequenceFor(_coachingId, examType: _examType);

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? DateTime(now.year + 1, 1, 24),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'Select your ${_examType.label} date',
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final enrollment = StudentEnrollment(
      coachingId: _coachingId,
      examType: _examType,
      examDate: _examDate,
      dailyMinutes: _dailyMinutes,
      currentPosition: _currentPosition,
      batchStartDate: DateTime.now(),
    );
    await ref.read(roadmapControllerProvider).saveEnrollment(enrollment);
    if (!mounted) return;
    context.go('/roadmap');
  }

  @override
  Widget build(BuildContext context) {
    final entries = _sequence.entries;
    // Keep current-position selection valid when coaching changes.
    if (_currentPosition >= entries.length) _currentPosition = 0;

    return GradientBackground(
      appBar: AppBar(
        title: const Text('Build Your Roadmap'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AnimatedEntrance(
            child: Text(
              'Let\'s sync your plan to your class',
              style: AppTypography.heading2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We\'ll line up practice and revision with what your coaching is '
            'teaching, and pace it toward your exam.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 24),

          // ── Exam target ──
          _SectionLabel('Which exam?'),
          const SizedBox(height: 10),
          Row(
            children: ExamType.values.map((e) {
              final selected = _examType == e;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: e == ExamType.values.first ? 10 : 0),
                  child: _ChoiceChip(
                    label: e.label,
                    selected: selected,
                    onTap: () => setState(() => _examType = e),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Coaching ──
          _SectionLabel('Where are you preparing?'),
          const SizedBox(height: 10),
          ..._institutes.map((c) => _CoachingTile(
                institute: c,
                selected: _coachingId == c.id,
                onTap: () => setState(() {
                  _coachingId = c.id;
                  _currentPosition = 0;
                }),
              )),
          const SizedBox(height: 24),

          // ── Current position in syllabus ──
          _SectionLabel('Which chapter is your class on now?'),
          const SizedBox(height: 6),
          Text(
            'Everything before it becomes revision; everything after becomes '
            'your upcoming plan.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 10),
          _CurrentChapterDropdown(
            entries: entries,
            value: _currentPosition,
            onChanged: (v) => setState(() => _currentPosition = v),
          ),
          const SizedBox(height: 24),

          // ── Exam date ──
          _SectionLabel('When is your exam?'),
          const SizedBox(height: 10),
          _DateField(
            date: _examDate,
            placeholder: 'Tap to pick your ${_examType.label} date',
            onTap: _pickExamDate,
          ),
          const SizedBox(height: 24),

          // ── Daily time budget ──
          _SectionLabel('Daily self-study time'),
          const SizedBox(height: 6),
          Text('${_dailyMinutes ~/ 60}h ${_dailyMinutes % 60}m per day',
              style: AppTypography.bodyMedium),
          Slider(
            value: _dailyMinutes.toDouble(),
            min: 30,
            max: 360,
            divisions: 11,
            activeColor: AppColors.primary,
            label: '${_dailyMinutes}m',
            onChanged: (v) => setState(() => _dailyMinutes = v.round()),
          ),
          const SizedBox(height: 24),

          AxioButton(
            label: 'Generate my roadmap',
            icon: LucideIcons.sparkles,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.heading3);
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
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.button.copyWith(
            color: selected ? AppColors.textOnPrimary : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _CoachingTile extends StatelessWidget {
  final CoachingInstitute institute;
  final bool selected;
  final VoidCallback onTap;
  const _CoachingTile({
    required this.institute,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                institute.isCustom ? LucideIcons.penTool : LucideIcons.graduationCap,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  institute.name,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ),
              if (selected)
                const Icon(LucideIcons.checkCircle2,
                    size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentChapterDropdown extends StatelessWidget {
  final List<SyllabusEntry> entries;
  final int value;
  final ValueChanged<int> onChanged;
  const _CurrentChapterDropdown({
    required this.entries,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 18),
          borderRadius: BorderRadius.circular(16),
          items: [
            for (var i = 0; i < entries.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  '${i + 1}. ${entries[i].chapterName}',
                  style: AppTypography.bodyLarge,
                ),
              ),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? date;
  final String placeholder;
  final VoidCallback onTap;
  const _DateField({
    required this.date,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              date == null
                  ? placeholder
                  : '${date!.day}/${date!.month}/${date!.year}',
              style: AppTypography.bodyLarge.copyWith(
                color: date == null ? AppColors.textLight : AppColors.textDark,
                fontWeight: date == null ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
