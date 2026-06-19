import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/models/enums.dart';
import '../../analytics/data/analytics_providers.dart';
import '../../practice/data/practice_providers.dart';
import '../domain/test_models.dart';
import '../data/test_providers.dart';
import 'widgets/question_view.dart';
import 'widgets/question_grid.dart';

class TestScreen extends ConsumerStatefulWidget {
  final String testId;

  /// In-memory session (adaptive practice). When provided, the screen runs
  /// this test directly instead of loading [testId] from the database.
  final Test? test;

  const TestScreen({super.key, required this.testId, this.test});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  Test? _test;
  int _currentIndex = 0;
  final Map<String, UserAnswer> _answers = {};
  late Duration _timeRemaining;
  Timer? _timer;
  bool _showGrid = false;
  bool _isLoading = true;

  String? _attemptId;
  DateTime _sessionStart = DateTime.now();
  DateTime _questionShownAt = DateTime.now();
  bool _submitting = false;

  static const int _marksPerQuestion = 4;

  @override
  void initState() {
    super.initState();
    _timeRemaining = const Duration(hours: 1); // Default, updated when test loads
    _loadTest();
  }

  Future<void> _loadTest() async {
    try {
      final repo = ref.read(testRepositoryProvider);
      // In-memory adaptive session takes precedence over a DB load.
      final test = widget.test ?? await repo.getTestWithQuestions(widget.testId);

      // A test with no questions cannot be run — bail out gracefully instead of
      // crashing on `test.questions[0]` (guards stale/empty seed tests).
      if (test.questions.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This test has no questions yet.')),
          );
          context.pop();
        }
        return;
      }

      // The student is practising now — cancel any pending skip nudge.
      NotificationService.instance.cancelPracticeReminder();

      // Create a real attempt up front so submission can persist + analyze.
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      String? attemptId;
      if (userId != null && test.questions.isNotEmpty) {
        try {
          final attempt = await repo.createAttempt(
            userId: userId,
            testId: test.id,
            totalMarks: test.questions.length * _marksPerQuestion,
          );
          attemptId = attempt.id;
        } catch (_) {
          // Offline / RLS — keep the test runnable; submission will no-op.
        }
      }

      if (mounted) {
        setState(() {
          _test = test;
          _attemptId = attemptId;
          _timeRemaining = test.duration;
          _isLoading = false;
          _sessionStart = DateTime.now();
          _questionShownAt = DateTime.now();
          for (final q in test.questions) {
            _answers[q.id] = UserAnswer(questionId: q.id);
          }
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load test: $e')),
        );
      }
    }
  }

  /// Accrue elapsed time onto the question being left, then reset the clock.
  void _accrueTime() {
    final test = _test;
    if (test == null || _currentIndex >= test.questions.length) return;
    final q = test.questions[_currentIndex];
    final secs = DateTime.now().difference(_questionShownAt).inSeconds;
    final a = _answers[q.id];
    if (a != null && secs > 0) {
      _answers[q.id] = a.copyWith(timeTaken: a.timeTaken + Duration(seconds: secs));
    }
    _questionShownAt = DateTime.now();
  }

  void _navigateTo(int index) {
    _accrueTime();
    setState(() {
      _currentIndex = index;
      _showGrid = false;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds <= 0) {
        timer.cancel();
        _submitTest();
        return;
      }
      setState(() {
        _timeRemaining -= const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectAnswer(String questionId, String answer) {
    setState(() {
      final existing = _answers[questionId]!;
      _answers[questionId] = existing.copyWith(selectedAnswer: answer);
    });
  }

  void _toggleReview(String questionId) {
    setState(() {
      final existing = _answers[questionId]!;
      _answers[questionId] = existing.copyWith(
        markedForReview: !existing.markedForReview,
      );
    });
  }

  void _goToQuestion(int index) => _navigateTo(index);

  Future<void> _submitTest() async {
    final test = _test;
    if (test == null || _submitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Test?'),
        content: Text(
          'You have answered ${_answers.values.where((a) => a.isAnswered).length} of ${test.totalQuestions} questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Test'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _accrueTime();
    _timer?.cancel();
    setState(() => _submitting = true);

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final attemptId = _attemptId;
    if (attemptId == null || userId == null) {
      // No persisted attempt (offline / not signed in) — leave gracefully.
      if (mounted) context.go('/');
      return;
    }

    // Grade locally for the score + AI-question usage stats.
    int correct = 0;
    for (final q in test.questions) {
      final a = _answers[q.id];
      if (a != null &&
          a.isAnswered &&
          a.selectedAnswer!.trim().toLowerCase() ==
              q.correctAnswer.trim().toLowerCase()) {
        correct++;
      }
    }

    final attempt = TestAttempt(
      id: attemptId,
      userId: userId,
      testId: test.id,
      startTime: _sessionStart,
      endTime: DateTime.now(),
      answers: _answers,
      score: correct * _marksPerQuestion,
      totalMarks: test.questions.length * _marksPerQuestion,
      status: TestAttemptStatus.submitted,
    );

    try {
      // Persist + run the local engine + the server weakness engine.
      await ref.read(testRepositoryProvider).submitAndAnalyze(
            attempt: attempt,
            questions: test.questions,
            testName: test.name,
            analyticsEngine: ref.read(analyticsEngineProvider),
          );

      // Feed the probation lifecycle for any AI-generated questions served.
      final practice = ref.read(practiceRepositoryProvider);
      for (final q in test.questions) {
        if (!q.id.startsWith('gen_')) continue;
        final a = _answers[q.id];
        if (a == null || !a.isAnswered) continue;
        final ok = a.selectedAnswer!.trim().toLowerCase() ==
            q.correctAnswer.trim().toLowerCase();
        practice.recordServed(q.id, correct: ok);
      }
    } catch (_) {
      // Submission failed — the attempt row still exists; results may be partial.
    }

    ref.read(activePracticeTestProvider.notifier).state = null;
    if (mounted) context.go('/results/$attemptId');
  }

  AnswerStatus _statusFor(int index) {
    final test = _test;
    if (test == null) return AnswerStatus.unanswered;
    if (index == _currentIndex) return AnswerStatus.current;
    final q = test.questions[index];
    final answer = _answers[q.id];
    if (answer == null) return AnswerStatus.unanswered;
    if (answer.markedForReview) return AnswerStatus.markedForReview;
    if (answer.isAnswered) return AnswerStatus.answered;
    return AnswerStatus.unanswered;
  }

  String get _timerText {
    final h = _timeRemaining.inHours;
    final m = _timeRemaining.inMinutes.remainder(60);
    final s = _timeRemaining.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_timeRemaining.inMinutes < 5) return AppColors.error;
    if (_timeRemaining.inMinutes < 10) return AppColors.warning;
    return AppColors.textDark;
  }

  @override
  Widget build(BuildContext context) {
    if (_submitting) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Analyzing your test…', style: AppTypography.bodyMedium),
            ],
          ),
        ),
      );
    }
    if (_isLoading || _test == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.cardBackground),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final test = _test!;
    final question = test.questions[_currentIndex];
    final currentAnswer = _answers[question.id];

    return Scaffold(
      backgroundColor: AppColors.background,
      // Top bar
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: _timerColor),
            const SizedBox(width: 6),
            Text(
              _timerText,
              style: AppTypography.heading3.copyWith(
                color: _timerColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showGrid = !_showGrid),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 18),
                const SizedBox(width: 4),
                Text('${_currentIndex + 1}/${test.totalQuestions}'),
              ],
            ),
          ),
          TextButton(
            onPressed: _submitTest,
            child: Text(
              'Submit',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Question area
              Expanded(
                child: QuestionView(
                  question: question,
                  selectedAnswer: currentAnswer?.selectedAnswer,
                  isMarkedForReview: currentAnswer?.markedForReview ?? false,
                  onAnswerSelected: (answer) =>
                      _selectAnswer(question.id, answer),
                  onToggleReview: () => _toggleReview(question.id),
                ),
              ),
              // Bottom navigation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      if (_currentIndex > 0)
                        OutlinedButton.icon(
                          onPressed: () => _navigateTo(_currentIndex - 1),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Previous'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMedium,
                            side: const BorderSide(color: AppColors.divider),
                          ),
                        )
                      else
                        const SizedBox(width: 100),
                      const Spacer(),
                      if (_currentIndex < test.totalQuestions - 1)
                        ElevatedButton.icon(
                          onPressed: () => _navigateTo(_currentIndex + 1),
                          icon: const Text('Next'),
                          label: const Icon(Icons.arrow_forward_rounded, size: 18),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Question grid overlay
          if (_showGrid)
            QuestionGrid(
              totalQuestions: test.totalQuestions,
              currentIndex: _currentIndex,
              statusFor: _statusFor,
              onQuestionTap: _goToQuestion,
              onClose: () => setState(() => _showGrid = false),
            ),
        ],
      ),
    );
  }
}
