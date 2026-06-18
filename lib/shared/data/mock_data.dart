import '../../features/auth/domain/user_model.dart';
import '../../features/test/domain/test_models.dart';
import '../../features/subjects/domain/subject_models.dart';
import '../models/enums.dart';

/// Mock data for Sprint 1 development.
/// Provides realistic sample data for all screens.
class MockData {
  MockData._();

  // ─── Current User ───
  static final UserModel currentUser = UserModel(
    id: 'user_001',
    email: 'rahul@example.com',
    name: 'Rahul Sharma',
    grade: '12th',
    subscriptionTier: SubscriptionTier.pro,
    subscriptionExpiry: DateTime(2027, 5, 1),
    createdAt: DateTime(2026, 1, 15),
    hasTakenDiagnostic: true,
    testsCompleted: 24,
    averageScore: 72.5,
    currentStreak: 7,
    topicsMastered: 18,
  );

  // ─── Score History ───
  static final List<Map<String, dynamic>> scoreHistory = [
    {'date': '1 Apr', 'score': 45.0},
    {'date': '8 Apr', 'score': 52.0},
    {'date': '15 Apr', 'score': 48.0},
    {'date': '22 Apr', 'score': 58.0},
    {'date': '29 Apr', 'score': 65.0},
    {'date': '5 May', 'score': 72.5},
  ];

  // ─── Subjects with Chapters ───
  static final List<Subject> subjects = [
    Subject(
      id: 'physics',
      type: SubjectType.physics,
      completionPercentage: 0.65,
      totalQuestions: 350,
      chapters: [
        Chapter(
          id: 'ph_mechanics',
          name: 'Mechanics',
          subjectId: 'physics',
          completionPercentage: 0.8,
          availableQuestions: 60,
          strength: TopicStrength.strong,
          topics: [
            Topic(id: 'ph_m_kinematics', name: 'Kinematics', chapterId: 'ph_mechanics', completionPercentage: 0.9, strength: TopicStrength.strong, availableQuestions: 20),
            Topic(id: 'ph_m_newton', name: "Newton's Laws", chapterId: 'ph_mechanics', completionPercentage: 0.85, strength: TopicStrength.strong, availableQuestions: 20),
            Topic(id: 'ph_m_work', name: 'Work, Energy & Power', chapterId: 'ph_mechanics', completionPercentage: 0.65, strength: TopicStrength.moderate, availableQuestions: 20),
          ],
        ),
        Chapter(
          id: 'ph_rotation',
          name: 'Rotational Motion',
          subjectId: 'physics',
          completionPercentage: 0.35,
          availableQuestions: 45,
          strength: TopicStrength.weak,
          topics: [
            Topic(id: 'ph_r_torque', name: 'Torque & Angular Momentum', chapterId: 'ph_rotation', completionPercentage: 0.3, strength: TopicStrength.weak, availableQuestions: 15),
            Topic(id: 'ph_r_moi', name: 'Moment of Inertia', chapterId: 'ph_rotation', completionPercentage: 0.4, strength: TopicStrength.weak, availableQuestions: 15),
            Topic(id: 'ph_r_rolling', name: 'Rolling Motion', chapterId: 'ph_rotation', completionPercentage: 0.35, strength: TopicStrength.weak, availableQuestions: 15),
          ],
        ),
        Chapter(
          id: 'ph_thermo',
          name: 'Thermodynamics',
          subjectId: 'physics',
          completionPercentage: 0.55,
          availableQuestions: 40,
          strength: TopicStrength.moderate,
          topics: [
            Topic(id: 'ph_t_laws', name: 'Laws of Thermodynamics', chapterId: 'ph_thermo', completionPercentage: 0.6, strength: TopicStrength.moderate, availableQuestions: 20),
            Topic(id: 'ph_t_kinetic', name: 'Kinetic Theory', chapterId: 'ph_thermo', completionPercentage: 0.5, strength: TopicStrength.moderate, availableQuestions: 20),
          ],
        ),
      ],
    ),
    Subject(
      id: 'chemistry',
      type: SubjectType.chemistry,
      completionPercentage: 0.58,
      totalQuestions: 320,
      chapters: [
        Chapter(
          id: 'ch_organic',
          name: 'Organic Chemistry',
          subjectId: 'chemistry',
          completionPercentage: 0.7,
          availableQuestions: 55,
          strength: TopicStrength.strong,
          topics: [
            Topic(id: 'ch_o_hydro', name: 'Hydrocarbons', chapterId: 'ch_organic', completionPercentage: 0.8, strength: TopicStrength.strong, availableQuestions: 20),
            Topic(id: 'ch_o_alcohol', name: 'Alcohols & Phenols', chapterId: 'ch_organic', completionPercentage: 0.6, strength: TopicStrength.moderate, availableQuestions: 20),
          ],
        ),
        Chapter(
          id: 'ch_physical',
          name: 'Physical Chemistry',
          subjectId: 'chemistry',
          completionPercentage: 0.4,
          availableQuestions: 50,
          strength: TopicStrength.weak,
          topics: [
            Topic(id: 'ch_p_equi', name: 'Chemical Equilibrium', chapterId: 'ch_physical', completionPercentage: 0.35, strength: TopicStrength.weak, availableQuestions: 15),
            Topic(id: 'ch_p_electro', name: 'Electrochemistry', chapterId: 'ch_physical', completionPercentage: 0.45, strength: TopicStrength.weak, availableQuestions: 20),
          ],
        ),
      ],
    ),
    Subject(
      id: 'mathematics',
      type: SubjectType.mathematics,
      completionPercentage: 0.72,
      totalQuestions: 380,
      chapters: [
        Chapter(
          id: 'ma_calculus',
          name: 'Calculus',
          subjectId: 'mathematics',
          completionPercentage: 0.85,
          availableQuestions: 70,
          strength: TopicStrength.strong,
          topics: [
            Topic(id: 'ma_c_diff', name: 'Differentiation', chapterId: 'ma_calculus', completionPercentage: 0.9, strength: TopicStrength.strong, availableQuestions: 25),
            Topic(id: 'ma_c_int', name: 'Integration', chapterId: 'ma_calculus', completionPercentage: 0.8, strength: TopicStrength.strong, availableQuestions: 25),
          ],
        ),
        Chapter(
          id: 'ma_algebra',
          name: 'Algebra',
          subjectId: 'mathematics',
          completionPercentage: 0.6,
          availableQuestions: 55,
          strength: TopicStrength.moderate,
          topics: [
            Topic(id: 'ma_a_matrix', name: 'Matrices & Determinants', chapterId: 'ma_algebra', completionPercentage: 0.55, strength: TopicStrength.moderate, availableQuestions: 20),
            Topic(id: 'ma_a_complex', name: 'Complex Numbers', chapterId: 'ma_algebra', completionPercentage: 0.65, strength: TopicStrength.moderate, availableQuestions: 20),
          ],
        ),
      ],
    ),
  ];

  // ─── Sample Questions (minimal set) ───
  static final List<Question> sampleQuestions = [
    Question(id: 'q1', text: 'A body is projected vertically upward with velocity 20 m/s. Find the maximum height reached. (Take g = 10 m/s²)', type: QuestionType.numerical, correctAnswer: '20', subjectId: 'physics', chapterId: 'ph_mechanics', topicId: 'ph_m_kinematics', difficulty: Difficulty.easy, explanation: 'Using v² = u² - 2gh, at max height v=0: h = u²/2g = 400/20 = 20m'),
    Question(id: 'q2', text: 'A block of mass 5 kg is placed on a frictionless surface. A force of 10 N is applied horizontally. What is the acceleration?', type: QuestionType.mcq, options: ['1 m/s²', '2 m/s²', '5 m/s²', '10 m/s²'], correctAnswer: '2 m/s²', subjectId: 'physics', chapterId: 'ph_mechanics', topicId: 'ph_m_newton', difficulty: Difficulty.easy, explanation: 'F = ma, so a = F/m = 10/5 = 2 m/s²'),
    Question(id: 'q3', text: 'The moment of inertia of a uniform disc of mass M and radius R about its diameter is:', type: QuestionType.mcq, options: ['MR²/4', 'MR²/2', 'MR²', '2MR²/5'], correctAnswer: 'MR²/4', subjectId: 'physics', chapterId: 'ph_rotation', topicId: 'ph_r_moi', difficulty: Difficulty.medium),
    Question(id: 'q4', text: 'In a Carnot engine, the temperature of the source is 500K and the sink is 300K. Find the efficiency in percentage.', type: QuestionType.numerical, correctAnswer: '40', subjectId: 'physics', chapterId: 'ph_thermo', topicId: 'ph_t_laws', difficulty: Difficulty.easy, explanation: 'η = 1 - T₂/T₁ = 1 - 300/500 = 0.4 = 40%'),
    Question(id: 'q5', text: 'Which of the following is an electrophilic addition reaction?', type: QuestionType.mcq, options: ['Addition of HBr to ethene', 'Hydrolysis of ester', 'Cannizzaro reaction', 'Aldol condensation'], correctAnswer: 'Addition of HBr to ethene', subjectId: 'chemistry', chapterId: 'ch_organic', topicId: 'ch_o_hydro', difficulty: Difficulty.easy),
    Question(id: 'q6', text: 'The pH of a 0.01 M HCl solution is:', type: QuestionType.mcq, options: ['1', '2', '3', '4'], correctAnswer: '2', subjectId: 'chemistry', chapterId: 'ch_physical', topicId: 'ch_p_equi', difficulty: Difficulty.easy, explanation: 'pH = -log[H⁺] = -log(0.01) = 2'),
    Question(id: 'q7', text: 'Find dy/dx if y = x³ + 3x² - 5x + 7', type: QuestionType.mcq, options: ['3x² + 6x - 5', '3x² + 6x + 5', 'x² + 6x - 5', '3x² - 6x - 5'], correctAnswer: '3x² + 6x - 5', subjectId: 'mathematics', chapterId: 'ma_calculus', topicId: 'ma_c_diff', difficulty: Difficulty.easy),
    Question(id: 'q8', text: 'Evaluate: ∫(2x + 3)dx from 0 to 2', type: QuestionType.numerical, correctAnswer: '10', subjectId: 'mathematics', chapterId: 'ma_calculus', topicId: 'ma_c_int', difficulty: Difficulty.easy, explanation: '∫(2x+3)dx = x²+3x. At x=2: 4+6=10. At x=0: 0. Answer = 10'),
    Question(id: 'q9', text: 'If A is a 3×3 matrix with |A| = 5, then |adj(A)| is:', type: QuestionType.mcq, options: ['5', '25', '125', '1/5'], correctAnswer: '25', subjectId: 'mathematics', chapterId: 'ma_algebra', topicId: 'ma_a_matrix', difficulty: Difficulty.medium, explanation: '|adj(A)| = |A|^(n-1) = 5² = 25'),
    Question(id: 'q10', text: 'The modulus of complex number (3 + 4i) is:', type: QuestionType.numerical, correctAnswer: '5', subjectId: 'mathematics', chapterId: 'ma_algebra', topicId: 'ma_a_complex', difficulty: Difficulty.easy, explanation: '|z| = √(3² + 4²) = √25 = 5'),
  ];

  // ─── Sample Diagnostic Test ───
  static Test get diagnosticTest => Test(
    id: 'test_diag_001',
    name: 'JEE Diagnostic Test',
    type: TestType.diagnostic,
    duration: const Duration(hours: 1),
    totalQuestions: sampleQuestions.length,
    subjectIds: ['physics', 'chemistry', 'mathematics'],
    questions: sampleQuestions,
  );

  // ─── Sample Test Attempt (completed) ───
  static TestAttempt get sampleAttempt => TestAttempt(
    id: 'attempt_001',
    userId: 'user_001',
    testId: 'test_diag_001',
    startTime: DateTime(2026, 5, 5, 10, 0),
    endTime: DateTime(2026, 5, 5, 10, 45),
    score: 7,
    totalMarks: 10,
    status: TestAttemptStatus.analyzed,
    answers: {
      'q1': UserAnswer(questionId: 'q1', selectedAnswer: '20', timeTaken: Duration(minutes: 2, seconds: 30)),
      'q2': UserAnswer(questionId: 'q2', selectedAnswer: '2 m/s²', timeTaken: Duration(minutes: 1, seconds: 15)),
      'q3': UserAnswer(questionId: 'q3', selectedAnswer: 'MR²/2', timeTaken: Duration(minutes: 3, seconds: 45), markedForReview: true),
      'q4': UserAnswer(questionId: 'q4', selectedAnswer: '40', timeTaken: Duration(minutes: 2)),
      'q5': UserAnswer(questionId: 'q5', selectedAnswer: 'Addition of HBr to ethene', timeTaken: Duration(minutes: 1, seconds: 30)),
      'q6': UserAnswer(questionId: 'q6', selectedAnswer: '2', timeTaken: Duration(minutes: 1)),
      'q7': UserAnswer(questionId: 'q7', selectedAnswer: '3x² + 6x - 5', timeTaken: Duration(minutes: 1, seconds: 45)),
      'q8': UserAnswer(questionId: 'q8', selectedAnswer: '10', timeTaken: Duration(minutes: 2, seconds: 15)),
      'q9': UserAnswer(questionId: 'q9', selectedAnswer: '5', timeTaken: Duration(minutes: 3)),
      'q10': UserAnswer(questionId: 'q10', selectedAnswer: '5', timeTaken: Duration(minutes: 1)),
    },
  );

  // ─── Weak/Strong Areas ───
  static final List<Map<String, dynamic>> areasToImprove = [
    {'subject': 'Physics', 'weakTopic': 'Rotational Motion', 'strongTopic': 'Mechanics', 'score': 0.65, 'color': SubjectType.physics},
    {'subject': 'Chemistry', 'weakTopic': 'Physical Chemistry', 'strongTopic': 'Organic Chemistry', 'score': 0.58, 'color': SubjectType.chemistry},
    {'subject': 'Mathematics', 'weakTopic': 'Probability', 'strongTopic': 'Calculus', 'score': 0.72, 'color': SubjectType.mathematics},
  ];
}
