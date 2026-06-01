import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/enums.dart';
import '../domain/subject_models.dart';

/// Repository for fetching subjects, chapters, topics, and user progress from Supabase.
class SubjectsRepository {
  final SupabaseClient _client;

  SubjectsRepository(this._client);

  /// Fetch all subjects with their chapters and topics.
  /// If [userId] is provided, merges user progress (completion/strength) data.
  Future<List<Subject>> getSubjects({String? userId}) async {
    // Fetch raw data
    final subjectsData = await _client.from('subjects').select().order('id');
    final chaptersData = await _client.from('chapters').select().order('id');
    final topicsData = await _client.from('topics').select().order('id');

    // Fetch user progress if userId provided
    Map<String, Map<String, dynamic>> progressMap = {};
    if (userId != null) {
      final progressData = await _client
          .from('user_progress')
          .select()
          .eq('user_id', userId);
      for (final p in progressData) {
        // Key by the most specific level: topic > chapter > subject
        final key = p['topic_id'] ?? p['chapter_id'] ?? p['subject_id'];
        if (key != null) {
          progressMap[key as String] = p;
        }
      }
    }

    // Build topic objects
    final topicsByChapter = <String, List<Topic>>{};
    for (final t in topicsData) {
      final chapterId = t['chapter_id'] as String;
      final progress = progressMap[t['id']];
      final topic = Topic.fromJson(
        t,
        completionPercentage: (progress?['completion_percentage'] as num?)?.toDouble(),
        strength: progress != null ? Topic.parseStrength(progress['strength'] as String?) : null,
      );
      topicsByChapter.putIfAbsent(chapterId, () => []).add(topic);
    }

    // Build chapter objects
    final chaptersBySubject = <String, List<Chapter>>{};
    for (final c in chaptersData) {
      final subjectId = c['subject_id'] as String;
      final topics = topicsByChapter[c['id']] ?? [];
      final progress = progressMap[c['id']];

      // If no explicit progress, compute from topics
      double chapterCompletion = (progress?['completion_percentage'] as num?)?.toDouble() ?? 0;
      TopicStrength chapterStrength = progress != null
          ? Topic.parseStrength(progress['strength'] as String?)
          : TopicStrength.moderate;

      if (progress == null && topics.isNotEmpty) {
        chapterCompletion = topics.map((t) => t.completionPercentage).reduce((a, b) => a + b) / topics.length;
        final avgCompletion = chapterCompletion;
        chapterStrength = avgCompletion >= 0.7
            ? TopicStrength.strong
            : avgCompletion >= 0.4
                ? TopicStrength.moderate
                : TopicStrength.weak;
      }

      final chapter = Chapter.fromJson(
        c,
        topics: topics,
        completionPercentage: chapterCompletion,
        strength: chapterStrength,
      );
      chaptersBySubject.putIfAbsent(subjectId, () => []).add(chapter);
    }

    // Build subject objects
    final subjects = <Subject>[];
    for (final s in subjectsData) {
      final chapters = chaptersBySubject[s['id']] ?? [];

      subjects.add(Subject.fromJson(
        s,
        chapters: chapters,
      ));
    }

    return subjects;
  }
}
