import '../../../shared/models/enums.dart';

/// Represents a user in the AxioStudy system.
class UserModel {
  final String id;
  final String email;
  final String name;
  final String? grade;
  final ExamType? examType;
  final bool onboardingCompleted;
  final SubscriptionTier subscriptionTier;
  final SubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionExpiry;
  final DateTime? trialEndsAt;
  final String? razorpayCustomerId;
  final String? razorpaySubscriptionId;
  final DateTime createdAt;
  final bool hasTakenDiagnostic;
  final int testsCompleted;
  final double averageScore;
  final int currentStreak;
  final int topicsMastered;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.grade,
    this.examType,
    this.onboardingCompleted = false,
    this.subscriptionTier = SubscriptionTier.free,
    this.subscriptionStatus = SubscriptionStatus.none,
    this.subscriptionExpiry,
    this.trialEndsAt,
    this.razorpayCustomerId,
    this.razorpaySubscriptionId,
    required this.createdAt,
    this.hasTakenDiagnostic = false,
    this.testsCompleted = 0,
    this.averageScore = 0.0,
    this.currentStreak = 0,
    this.topicsMastered = 0,
  });

  /// Whether the user still has app access (inside trial or actively billed).
  bool get isEntitled => subscriptionStatus.isEntitled;

  /// Create from Supabase `profiles` row.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      grade: json['grade'] as String?,
      examType: ExamType.fromName(json['exam_type'] as String?),
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      subscriptionTier: _parseTier(json['subscription_tier'] as String?),
      subscriptionStatus:
          SubscriptionStatus.fromDb(json['subscription_status'] as String?),
      subscriptionExpiry: json['subscription_expiry'] != null
          ? DateTime.parse(json['subscription_expiry'] as String)
          : null,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      razorpayCustomerId: json['razorpay_customer_id'] as String?,
      razorpaySubscriptionId: json['razorpay_subscription_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      hasTakenDiagnostic: json['has_taken_diagnostic'] as bool? ?? false,
      testsCompleted: json['tests_completed'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['current_streak'] as int? ?? 0,
      topicsMastered: json['topics_mastered'] as int? ?? 0,
    );
  }

  /// Convert to JSON for Supabase upsert.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'grade': grade,
      'exam_type': examType?.name,
      'onboarding_completed': onboardingCompleted,
      'subscription_tier': subscriptionTier.name,
      'subscription_status': subscriptionStatus.dbValue,
      'subscription_expiry': subscriptionExpiry?.toIso8601String(),
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'razorpay_customer_id': razorpayCustomerId,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'has_taken_diagnostic': hasTakenDiagnostic,
      'tests_completed': testsCompleted,
      'average_score': averageScore,
      'current_streak': currentStreak,
      'topics_mastered': topicsMastered,
    };
  }

  static SubscriptionTier _parseTier(String? tier) {
    switch (tier) {
      case 'basic':
        return SubscriptionTier.basic;
      case 'premium':
        return SubscriptionTier.premium;
      case 'professional':
        return SubscriptionTier.professional;
      default:
        return SubscriptionTier.free;
    }
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? grade,
    ExamType? examType,
    bool? onboardingCompleted,
    SubscriptionTier? subscriptionTier,
    SubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionExpiry,
    DateTime? trialEndsAt,
    String? razorpayCustomerId,
    String? razorpaySubscriptionId,
    DateTime? createdAt,
    bool? hasTakenDiagnostic,
    int? testsCompleted,
    double? averageScore,
    int? currentStreak,
    int? topicsMastered,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      examType: examType ?? this.examType,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      razorpayCustomerId: razorpayCustomerId ?? this.razorpayCustomerId,
      razorpaySubscriptionId:
          razorpaySubscriptionId ?? this.razorpaySubscriptionId,
      createdAt: createdAt ?? this.createdAt,
      hasTakenDiagnostic: hasTakenDiagnostic ?? this.hasTakenDiagnostic,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      averageScore: averageScore ?? this.averageScore,
      currentStreak: currentStreak ?? this.currentStreak,
      topicsMastered: topicsMastered ?? this.topicsMastered,
    );
  }
}
