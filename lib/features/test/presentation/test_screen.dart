import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/models/enums.dart';
import '../domain/test_models.dart';
import 'widgets/question_view.dart';
import 'widgets/question_grid.dart';

class TestScreen extends StatefulWidget {
  final String testId;
  const TestScreen({super.key, required this.testId});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late Test _test;
  int _currentIndex = 0;
  final Map<String, UserAnswer> _answers = {};
  late Duration _timeRemaining;
  Timer? _timer;
  bool _showGrid = false;

  @override
  void initState() {
    super.initState();
    _test = MockData.diagnosticTest;
    _timeRemaining = _test.duration;
    _startTimer();
    // Initialize empty answers
    for (final q in _test.questions) {
      _answers[q.id] = UserAnswer(questionId: q.id);
    }
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

  void _goToQuestion(int index) {
    setState(() {
      _currentIndex = index;
      _showGrid = false;
    });
  }

  void _submitTest() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Test?'),
        content: Text(
          'You have answered ${_answers.values.where((a) => a.isAnswered).length} of ${_test.totalQuestions} questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue Test'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/results/attempt_001');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  AnswerStatus _statusFor(int index) {
    if (index == _currentIndex) return AnswerStatus.current;
    final q = _test.questions[index];
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
    final question = _test.questions[_currentIndex];
    final currentAnswer = _answers[question.id];

    return Scaffold(
      backgroundColor: AppColors.backgroundGradientEnd,
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
                Text('${_currentIndex + 1}/${_test.totalQuestions}'),
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
                          onPressed: () =>
                              setState(() => _currentIndex--),
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
                      if (_currentIndex < _test.totalQuestions - 1)
                        ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _currentIndex++),
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
              totalQuestions: _test.totalQuestions,
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
