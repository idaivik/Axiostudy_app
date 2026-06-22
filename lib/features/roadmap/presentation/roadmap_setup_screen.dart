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
  ExamType _examType = ExamType.jee;
  int _dailyMinutes = 120;
  int _currentPosition = 0;
  bool _saving = false;

  // Everyone shares the standard (NCERT-order) baseline now — the coaching
  // picker is gone. The exam date is derived from the track, not asked for.
  static const _coachingId = 'standard';

  SyllabusSequence get _sequence =>
      RoadmapSeedData.sequenceFor(_coachingId, examType: _examType);

  DateTime get _examDate => _examType.nextExamDate();

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

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.calendarClock, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'We\'ll pace you toward the next ${_examType.label} — ${_fmtDate(_examDate)}.',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Current position in syllabus ──
          _SectionLabel('How far have you studied?'),
          const SizedBox(height: 6),
          Text(
            'Everything up to here becomes revision; everything after becomes '
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

