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
