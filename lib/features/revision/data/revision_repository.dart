import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/revision_models.dart';
import '../domain/spaced_repetition.dart';

/// Assembles the spaced-repetition revision plan (Bucket 3A · Feature 1).
///
/// Reads — never writes — the engine's curve rows: it merges `topic_review_state`
/// (the SM-2 schedule the push engine maintains) with `topic_performance` (the
/// weakness signal), so the same rows the daily reminder advances are what the
/// student sees and ticks off here. "Mark reviewed" advances the curve through
/// the `mark_topic_reviewed` RPC (the only client-writable path — the table is
/// RLS read-only). The last good plan is cached to SharedPreferences so the
/// screen still renders offline.
class RevisionRepository {
  final SupabaseClient _client;
  RevisionRepository(this._client);

  static const _cacheKeyPrefix = 'revision_plan_';

  /// Build the current plan for [userId]. Falls back to the cached plan on any
  /// network/read error so the surface works without a connection.
  Future<RevisionPlan> loadPlan(String userId) async {
    try {
      final results = await Future.wait([
        _client.from('topic_performance').select(
            'topic_id, chapter_id, subject_id, accuracy, strength, total_questions'),
        _client
            .from('topic_review_state')
            .select('topic_id, interval_days, ease, reps, last_reviewed_at, next_due_at'),
      ]);
      final perfRows = (results[0] as List).cast<Map<String, dynamic>>();
      final stateRows = (results[1] as List).cast<Map<String, dynamic>>();

      final stateByTopic = {
        for (final r in stateRows) r['topic_id'] as String: r,
      };

      final items = <RevisionItem>[];
      final seen = <String>{};
      for (final p in perfRows) {
        final topicId = p['topic_id'] as String?;
        if (topicId == null || topicId.isEmpty) continue;
        final strength = p['strength'] as String? ?? 'moderate';
        final attempted = (p['total_questions'] as num?)?.toInt() ?? 0;
        final state = stateByTopic[topicId];

        // Revision candidates: anything already on a curve, plus attempted
        // weak/moderate topics. A strong topic never reviewed isn't noise we
        // want on the plan.
        final tracked = state != null;
        if (!tracked && (attempted == 0 || strength == 'strong')) continue;

        items.add(RevisionItem(
          topicId: topicId,
          chapterId: p['chapter_id'] as String? ?? '',
          subjectId: p['subject_id'] as String? ?? '',
          displayName: _displayName(topicId),
          srs: state == null
              ? SrsState.fresh
              : SrsState(
                  intervalDays: (state['interval_days'] as num?)?.toInt() ?? 1,
                  ease: (state['ease'] as num?)?.toDouble() ?? 2.5,
                  reps: (state['reps'] as num?)?.toInt() ?? 0,
                ),
          dueAt: state == null ? null : _parseDate(state['next_due_at']),
          lastReviewedAt: state == null ? null : _parseDate(state['last_reviewed_at']),
          accuracy: (p['accuracy'] as num?)?.toDouble() ?? 0,
          strength: strength,
        ));
        seen.add(topicId);
      }

      final plan = RevisionPlan(items: items, generatedAt: DateTime.now());
      await _cachePlan(userId, plan);
      return plan;
    } catch (_) {
      return await _cachedPlan(userId) ?? RevisionPlan.empty;
    }
  }

  /// Advance (or seed) a topic's curve after the student reviews it. [quality]
  /// is the 0–5 SM-2 self-rating (the screen sends 5 for "Got it", 2 for "Still
  /// shaky"). Returns the new state on success, null on failure.
  Future<SrsState?> markReviewed(String topicId, {int quality = 5}) async {
    try {
      final res = await _client.rpc('mark_topic_reviewed', params: {
        'p_topic_id': topicId,
        'p_quality': quality,
      });
      final map = res is Map<String, dynamic> ? res : null;
      if (map == null || map['ok'] != true) return null;
      return SrsState(
        intervalDays: (map['interval_days'] as num?)?.toInt() ?? 1,
        ease: (map['ease'] as num?)?.toDouble() ?? 2.5,
        reps: (map['reps'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePlan(String userId, RevisionPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKeyPrefix$userId', jsonEncode(plan.toJson()));
    } catch (_) {/* cache is best-effort */}
  }

  Future<RevisionPlan?> _cachedPlan(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cacheKeyPrefix$userId');
      if (raw == null) return null;
      return RevisionPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  /// "phys_kinematics_projectile_motion" → "Projectile Motion" (mirrors the
  /// analytics topic-name derivation so labels read the same across screens).
  static String _displayName(String topicId) {
    final parts = topicId.split('_');
    final tail = parts.length >= 3
        ? parts.sublist(2)
        : parts.length >= 2
            ? parts.sublist(1)
            : parts;
    final words = tail
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1));
    final name = words.join(' ');
    return name.isEmpty ? topicId : name;
  }
}
