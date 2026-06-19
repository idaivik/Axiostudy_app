import '../../subscription/domain/meter_outcome.dart';
import 'study_note.dart';

/// Result of the `generate-notes` edge call (Feature 2). Couples the metered
/// [outcome] with the generated [note] so the UI renders the note on `ok` and
/// the shared locked/cap states otherwise.
class NoteResult {
  final MeterOutcome outcome;
  final StudyNote? note;

  /// True when the note came from the cache (no meter spent this open).
  final bool cached;

  const NoteResult({required this.outcome, this.note, this.cached = false});

  factory NoteResult.fromJson(Map<String, dynamic> j) {
    final content = j['note'];
    return NoteResult(
      outcome: MeterOutcome.fromJson(j),
      note: content is Map<String, dynamic>
          ? StudyNote.fromContent(content, j['level'] as String?)
          : null,
      cached: j['cached'] == true,
    );
  }

  /// A transient/unknown failure (network, unexpected body).
  static const NoteResult error =
      NoteResult(outcome: MeterOutcome(MeterStatus.error));
}
