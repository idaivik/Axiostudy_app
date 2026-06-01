import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_model.dart';
import '../../../shared/data/mock_data.dart';

/// Auth state — true if user is logged in.
final authStateProvider = StateProvider<bool>((ref) => false);

/// Current user provider — returns mock user for Sprint 1.
final currentUserProvider = Provider<UserModel?>((ref) {
  final isLoggedIn = ref.watch(authStateProvider);
  return isLoggedIn ? MockData.currentUser : null;
});

/// Whether the user has taken the diagnostic test.
final hasTakenDiagnosticProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.hasTakenDiagnostic ?? false;
});
