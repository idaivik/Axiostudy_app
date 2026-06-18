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

  /// Store that processed the subscription ('play_store' / 'app_store').
  final String? subscriptionPlatform;

  /// Store product identifier of the active subscription.
  final String? storeProductId;

  /// Latest store transaction id for the subscription.
  final String? storeTransactionId;
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
    this.subscriptionPlatform,
    this.storeProductId,
    this.storeTransactionId,
    required this.createdAt,
    this.hasTakenDiagnostic = false,
    this.testsCompleted = 0,
    this.averageScore = 0.0,
    this.currentStreak = 0,
    this.topicsMastered = 0,
  });

  /// Whether the user still has app access (inside trial or actively billed).
  bool get isEntitled => subscriptionStatus.isEntitled;

  /// Whether the user currently retains paid access — the predicate the app gates
  /// on (including re-locking a lapsed account). Covers the trial and active
  /// billing, plus a **cancelled or past-due** subscription that is still inside
  /// its already-paid period: the store grants access until the period ends, so
  /// we must too. Returns false once the store marks the subscription expired
  /// (`none`) or that paid period has elapsed.
  bool get hasActiveAccess {
    if (subscriptionStatus.isEntitled) return true; // trialing | active
    if (subscriptionStatus == SubscriptionStatus.none) return false;
    // cancelled / past_due — honour whatever paid time is left on the period.
    final expiry = subscriptionExpiry;
    return expiry != null && expiry.isAfter(DateTime.now());
  }

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
      subscriptionPlatform: json['subscription_platform'] as String?,
      storeProductId: json['store_product_id'] as String?,
      storeTransactionId: json['store_transaction_id'] as String?,
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
      'subscription_platform': subscriptionPlatform,
      'store_product_id': storeProductId,
      'store_transaction_id': storeTransactionId,
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
      case 'pro':
      // Legacy values still present on older rows map to the consolidated `pro`.
      case 'premium':
      case 'professional':
        return SubscriptionTier.pro;
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
    String? subscriptionPlatform,
    String? storeProductId,
    String? storeTransactionId,
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
      subscriptionPlatform: subscriptionPlatform ?? this.subscriptionPlatform,
      storeProductId: storeProductId ?? this.storeProductId,
      storeTransactionId: storeTransactionId ?? this.storeTransactionId,
      createdAt: createdAt ?? this.createdAt,
      hasTakenDiagnostic: hasTakenDiagnostic ?? this.hasTakenDiagnostic,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      averageScore: averageScore ?? this.averageScore,
      currentStreak: currentStreak ?? this.currentStreak,
      topicsMastered: topicsMastered ?? this.topicsMastered,
    );
  }
}
