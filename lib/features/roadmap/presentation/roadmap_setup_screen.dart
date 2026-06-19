import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart' as shared;
import '../../auth/data/auth_providers.dart';
import '../../subjects/domain/chapter_grade.dart';
import '../data/roadmap_providers.dart';
import '../data/roadmap_seed_data.dart';
import '../domain/roadmap_models.dart';

/// Setup flow that captures everything the planner needs: which coaching the
/// student is in (so the plan matches class order), where their class currently
/// is, and how much time they have per day. The target exam is read from the
/// profile (set during onboarding) rather than asked again here.
class RoadmapSetupScreen extends ConsumerStatefulWidget {
  const RoadmapSetupScreen({super.key});

  @override
  ConsumerState<RoadmapSetupScreen> createState() => _RoadmapSetupScreenState();
}

class _RoadmapSetupScreenState extends ConsumerState<RoadmapSetupScreen> {
  String _coachingId = 'allen';
  DateTime? _examDate;
  int _dailyMinutes = 120;
  int _currentPosition = 0;
  bool _saving = false;

  /// The target exam comes from the profile chosen at onboarding; default to
  /// JEE if it hasn't loaded yet.
  ExamType _examTypeFrom(shared.ExamType? profileExam) =>
      profileExam == shared.ExamType.neet ? ExamType.neet : ExamType.jee;

  Future<void> _pickExamDate(String examLabel) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? DateTime(now.year + 1, 1, 24),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'Select your $examLabel date',
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Future<void> _pickCoaching() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoachingPickerSheet(selectedId: _coachingId),
    );
    if (id != null) {
      setState(() {
        _coachingId = id;
        _currentPosition = 0;
      });
    }
  }

  Future<void> _pickChapter(List<SyllabusEntry> entries) async {
    final pos = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ChapterPickerSheet(entries: entries, selected: _currentPosition),
    );
    if (pos != null) setState(() => _currentPosition = pos);
  }

  Future<void> _save(ExamType examType) async {
    setState(() => _saving = true);
    final enrollment = StudentEnrollment(
      coachingId: _coachingId,
      examType: examType,
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
    final examType =
        _examTypeFrom(ref.watch(currentUserProvider).valueOrNull?.examType);
    final sequence =
        RoadmapSeedData.sequenceFor(_coachingId, examType: examType);
    final entries = sequence.entries;
    // Keep current-position selection valid when coaching/exam changes.
    if (_currentPosition >= entries.length) _currentPosition = 0;

    final institute = RoadmapSeedData.instituteById(_coachingId);
    final currentEntry = entries.isEmpty ? null : entries[_currentPosition];

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          AnimatedEntrance(
            child: Text('Sync your plan to your class',
                style: AppTypography.heading2),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll pace practice and revision toward your exam.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          _ExamPill(examType: examType),
          const SizedBox(height: 32),

          // ── Coaching ──
          const _FieldLabel('Your coaching'),
          const SizedBox(height: 10),
          _SelectField(
            icon: institute.isCustom
                ? LucideIcons.penTool
                : LucideIcons.graduationCap,
            iconColor: AppColors.primary,
            value: institute.name,
            onTap: _pickCoaching,
          ),
          const SizedBox(height: 28),

          // ── Current position in syllabus ──
          const _FieldLabel('Where your class is now'),
          const SizedBox(height: 4),
          Text('Earlier chapters become revision; later ones, your plan.',
              style: AppTypography.caption),
          const SizedBox(height: 10),
          _SelectField(
            icon: LucideIcons.bookMarked,
            iconColor: currentEntry == null
                ? AppColors.textLight
                : _SubjectStyle.of(currentEntry.subjectId).color,
            value: currentEntry?.chapterName ?? 'No chapters',
            tag: currentEntry == null
                ? null
                : chapterClassLevel(currentEntry.chapterId).label,
            onTap: entries.isEmpty ? null : () => _pickChapter(entries),
          ),
          const SizedBox(height: 28),

          // ── Exam date ──
          const _FieldLabel('Exam date'),
          const SizedBox(height: 10),
          _DateField(
            date: _examDate,
            placeholder: 'Tap to pick your ${examType.label} date',
            onTap: () => _pickExamDate(examType.label),
          ),
          const SizedBox(height: 28),

          // ── Daily time budget ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _FieldLabel('Daily study time'),
              Text(_formatMinutes(_dailyMinutes),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _dailyMinutes.toDouble(),
              min: 30,
              max: 720, // up to 12 h/day for full-time aspirants
              divisions: 23, // 30-minute steps
              activeColor: AppColors.primary,
              label: _formatMinutes(_dailyMinutes),
              onChanged: (v) => setState(() => _dailyMinutes = v.round()),
            ),
          ),
          const SizedBox(height: 32),

          AxioButton(
            label: 'Generate my roadmap',
            icon: LucideIcons.sparkles,
            isLoading: _saving,
            onPressed: _saving ? null : () => _save(examType),
          ),
        ],
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Read-only badge showing the exam the plan is built for (drawn from profile).
class _ExamPill extends StatelessWidget {
  final ExamType examType;
  const _ExamPill({required this.examType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.target, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Preparing for ${examType.label}',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      );
}

/// A tappable input that shows the current selection and opens a picker sheet.
/// Used for both the coaching and the current-chapter fields.
class _SelectField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String? tag;
  final VoidCallback? onTap;
  const _SelectField({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: AppTypography.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              _Tag(tag!),
            ],
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown,
                size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for the Class 11 / Class 12 badge.
class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: AppColors.textMedium),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.calendar,
                  size: 18, color: AppColors.primary),
            ),
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

// ───────────────────────── Picker sheets ─────────────────────────

/// Scrollable, searchable bottom sheet for choosing a coaching institute.
/// Scales to a long list of centres without crowding the setup form.
class _CoachingPickerSheet extends StatefulWidget {
  final String selectedId;
  const _CoachingPickerSheet({required this.selectedId});

  @override
  State<_CoachingPickerSheet> createState() => _CoachingPickerSheetState();
}

class _CoachingPickerSheetState extends State<_CoachingPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = RoadmapSeedData.institutes
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return _SheetScaffold(
      title: 'Your coaching',
      onSearch: (v) => setState(() => _query = v),
      searchHint: 'Search coaching centres',
      child: results.isEmpty
          ? const _EmptyResult()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final c = results[i];
                final selected = c.id == widget.selectedId;
                return _SheetRow(
                  icon: c.isCustom
                      ? LucideIcons.penTool
                      : LucideIcons.graduationCap,
                  iconColor: AppColors.primary,
                  title: c.name,
                  selected: selected,
                  onTap: () => Navigator.pop(context, c.id),
                );
              },
            ),
    );
  }
}

/// Searchable bottom sheet for the current chapter, grouped by subject with a
/// Class 11 / Class 12 badge — so a chapter is easy to find in context rather
/// than buried in one long undifferentiated list.
class _ChapterPickerSheet extends StatefulWidget {
  final List<SyllabusEntry> entries;
  final int selected;
  const _ChapterPickerSheet({required this.entries, required this.selected});

  @override
  State<_ChapterPickerSheet> createState() => _ChapterPickerSheetState();
}

class _ChapterPickerSheetState extends State<_ChapterPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = widget.entries
        .where((e) => e.chapterName.toLowerCase().contains(q))
        .toList();

    // Group by subject, preserving the order subjects first appear.
    final groups = <String, List<SyllabusEntry>>{};
    for (final e in filtered) {
      groups.putIfAbsent(e.subjectId, () => []).add(e);
    }

    return _SheetScaffold(
      title: 'Where your class is now',
      onSearch: (v) => setState(() => _query = v),
      searchHint: 'Search chapters',
      child: filtered.isEmpty
          ? const _EmptyResult()
          : ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final entry in groups.entries) ...[
                  _SubjectHeader(subjectId: entry.key),
                  for (final e in entry.value)
                    _SheetRow(
                      icon: LucideIcons.bookMarked,
                      iconColor: _SubjectStyle.of(e.subjectId).color,
                      title: e.chapterName,
                      tag: chapterClassLevel(e.chapterId).label,
                      selected: e.position == widget.selected,
                      onTap: () => Navigator.pop(context, e.position),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Shared sheet chrome: rounded top, drag handle, title and a search field,
/// with the result list given the remaining height.
class _SheetScaffold extends StatelessWidget {
  final String title;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final Widget child;
  const _SheetScaffold({
    required this.title,
    required this.searchHint,
    required this.onSearch,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppTypography.heading2),
            ),
            const SizedBox(height: 14),
            TextField(
              autofocus: false,
              onChanged: onSearch,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textLight),
                prefixIcon: const Icon(LucideIcons.search,
                    size: 18, color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Subject group header inside the chapter picker.
class _SubjectHeader extends StatelessWidget {
  final String subjectId;
  const _SubjectHeader({required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final style = _SubjectStyle.of(subjectId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(style.icon, size: 16, color: style.color),
          const SizedBox(width: 8),
          Text(
            style.name.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(color: style.color),
          ),
        ],
      ),
    );
  }
}

/// A single selectable row inside a picker sheet.
class _SheetRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? tag;
  final bool selected;
  final VoidCallback onTap;
  const _SheetRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textDark,
                ),
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              _Tag(tag!),
            ],
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(LucideIcons.checkCircle2,
                  size: 18, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('No matches', style: AppTypography.bodyMedium),
    );
  }
}

/// Display metadata (name, colour, icon) for a roadmap subject id.
class _SubjectStyle {
  final String name;
  final Color color;
  final IconData icon;
  const _SubjectStyle(this.name, this.color, this.icon);

  static _SubjectStyle of(String subjectId) {
    switch (subjectId) {
      case 'chem':
        return const _SubjectStyle(
            'Chemistry', AppColors.chemistry, LucideIcons.flaskConical);
      case 'math':
        return const _SubjectStyle(
            'Mathematics', AppColors.mathematics, LucideIcons.sigma);
      case 'bio':
        return const _SubjectStyle(
            'Biology', AppColors.biology, LucideIcons.microscope);
      case 'phys':
      default:
        return const _SubjectStyle(
            'Physics', AppColors.physics, LucideIcons.atom);
    }
  }
}
