import '../../../shared/models/enums.dart';

/// Represents a user in the AxioStudy system.
class UserModel {
  final String id;
  final String email;
  final String name;
  final String? grade;
  final SubscriptionTier subscriptionTier;
  final DateTime? subscriptionExpiry;
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
    this.subscriptionTier = SubscriptionTier.free,
    this.subscriptionExpiry,
    required this.createdAt,
    this.hasTakenDiagnostic = false,
    this.testsCompleted = 0,
    this.averageScore = 0.0,
    this.currentStreak = 0,
    this.topicsMastered = 0,
  });

  /// Create from Supabase `profiles` row.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      grade: json['grade'] as String?,
      subscriptionTier: _parseTier(json['subscription_tier'] as String?),
      subscriptionExpiry: json['subscription_expiry'] != null
          ? DateTime.parse(json['subscription_expiry'] as String)
          : null,
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
      'subscription_tier': subscriptionTier.name,
      'subscription_expiry': subscriptionExpiry?.toIso8601String(),
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
    SubscriptionTier? subscriptionTier,
    DateTime? subscriptionExpiry,
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
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      createdAt: createdAt ?? this.createdAt,
      hasTakenDiagnostic: hasTakenDiagnostic ?? this.hasTakenDiagnostic,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      averageScore: averageScore ?? this.averageScore,
      currentStreak: currentStreak ?? this.currentStreak,
      topicsMastered: topicsMastered ?? this.topicsMastered,
    );
  }
}
