import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/presentation/ai_locked_card.dart';
import '../../subscription/presentation/feature_gate.dart';
import '../../subscription/presentation/paywall_screen.dart';
import '../data/notes_providers.dart';
import '../domain/note_result.dart';
import '../domain/study_note.dart';

/// Feature 2 (Pro) — AI study notes for one topic, pitched at the student's
/// level. Opening generates-and-caches once (one ai_note); re-opening reads the
/// cache for free; "Regenerate" is an explicit re-spend. Pro-gated; Basic sees
/// the upsell, trial/cap states use the shared AiLockedCard.
class TopicNotesScreen extends StatelessWidget {
  final String topicId;
  final String? topicName;
  final String? chapterId;
  final String? subjectId;

  const TopicNotesScreen({
    super.key,
    required this.topicId,
    this.topicName,
    this.chapterId,
    this.subjectId,
  });

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(topicName?.trim().isNotEmpty == true ? topicName! : 'Study Notes'),
      ),
      child: FeatureGate(
        feature: Feature.aiNotes,
        locked: (_) => const _NotesLocked(),
        child: (_) => _NotesBody(
          topicId: topicId,
          topicName: topicName,
          chapterId: chapterId,
          subjectId: subjectId,
        ),
      ),
    );
  }
}

class _NotesBody extends ConsumerStatefulWidget {
  final String topicId;
  final String? topicName;
  final String? chapterId;
  final String? subjectId;

  const _NotesBody({
    required this.topicId,
    this.topicName,
    this.chapterId,
    this.subjectId,
  });

  @override
  ConsumerState<_NotesBody> createState() => _NotesBodyState();
}

class _NotesBodyState extends ConsumerState<_NotesBody> {
  NoteResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(regenerate: false);
  }

  Future<void> _load({required bool regenerate}) async {
    setState(() => _loading = true);
    final result = await ref.read(notesRepositoryProvider).getNote(
          topicId: widget.topicId,
          topicName: widget.topicName,
          chapterId: widget.chapterId,
          subjectId: widget.subjectId,
          regenerate: regenerate,
        );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _confirmRegenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate notes?'),
        content: const Text(
            'This writes a fresh set of notes and uses one of your monthly AI '
            'notes. Your current notes will be replaced.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok == true) _load(regenerate: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Writing notes pitched to your level…'),
          ],
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const Center(child: Text('Something went wrong.'));
    }

    if (!result.outcome.ok || result.note == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AiLockedCard(
          status: result.outcome.status,
          featureTitle: 'study note',
        ),
      );
    }

    return _NoteView(
      note: result.note!,
      cached: result.cached,
      remaining: result.outcome.remaining,
      onRegenerate: _confirmRegenerate,
    );
  }
}

class _NoteView extends StatelessWidget {
  final StudyNote note;
  final bool cached;
  final int? remaining;
  final VoidCallback onRegenerate;

  const _NoteView({
    required this.note,
    required this.cached,
    required this.remaining,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _LevelChip(label: note.levelLabel),
        const SizedBox(height: 16),
        if (note.concept.isNotEmpty) ...[
          _SectionTitle(icon: LucideIcons.lightbulb, title: 'The idea'),
          const SizedBox(height: 8),
          Text(note.concept,
              style: AppTypography.bodyLarge.copyWith(height: 1.5, fontSize: 15)),
          const SizedBox(height: 20),
        ],
        if (note.keyPoints.isNotEmpty) ...[
          _SectionTitle(icon: LucideIcons.listChecks, title: 'Key points'),
          const SizedBox(height: 8),
          ...note.keyPoints.map((p) => _Bullet(text: p, color: AppColors.primary)),
          const SizedBox(height: 20),
        ],
        if (note.formulas.isNotEmpty) ...[
          _SectionTitle(icon: LucideIcons.sigma, title: 'Key formulas'),
          const SizedBox(height: 8),
          ...note.formulas.map((f) => _FormulaRow(formula: f)),
          const SizedBox(height: 20),
        ],
        if (note.commonMistakes.isNotEmpty) ...[
          _SectionTitle(icon: LucideIcons.alertTriangle, title: 'Common mistakes'),
          const SizedBox(height: 8),
          ...note.commonMistakes.map((m) => _Bullet(text: m, color: AppColors.weak)),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onRegenerate,
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: const Text('Regenerate (uses 1 AI note)'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            cached
                ? 'Saved notes — re-opening is always free.'
                : remaining != null
                    ? '$remaining AI notes left this month.'
                    : 'Notes generated.',
            style: AppTypography.caption,
          ),
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  const _LevelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.gauge, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.heading3),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;
  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTypography.bodyMedium.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// Renders a note formula via flutter_math_fork, falling back to the raw TeX so
/// a bad row never blanks the section (same approach as the formula-bank card).
class _FormulaRow extends StatelessWidget {
  final NoteFormula formula;
  const _FormulaRow({required this.formula});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyLarge.copyWith(fontSize: 16, color: AppColors.textDark);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (formula.name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(formula.name,
                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              formula.tex,
              mathStyle: MathStyle.text,
              textStyle: style,
              onErrorFallback: (_) =>
                  Text(formula.tex, style: style.copyWith(fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesLocked extends StatelessWidget {
  const _NotesLocked();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(LucideIcons.bookOpen, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('AI study notes', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text(
              'A Pro feature: notes written for each topic and pitched to exactly '
              'how strong you are on it.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  PaywallScreen.showUpgrade(context, tier: SubscriptionTier.pro),
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Upgrade to Pro'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
