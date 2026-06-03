import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/models/enums.dart';
import '../domain/user_model.dart';
import 'auth_repository.dart';

/// Test profile used when guest mode is active.
final _guestProfile = UserModel(
  id: 'guest-001',
  email: 'test@axiostudy.com',
  name: 'Ujjwal Kalra',
  grade: '12th',
  subscriptionTier: SubscriptionTier.premium,
  createdAt: DateTime(2025, 1, 1),
  hasTakenDiagnostic: true,
  testsCompleted: 12,
  averageScore: 72.5,
  currentStreak: 7,
  topicsMastered: 34,
);

/// Guest mode toggle — true means skip Supabase auth entirely.
final guestModeProvider = StateProvider<bool>((ref) => false);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((authState) {
    return authState.session != null;
  });
});

/// Logged in if Supabase session exists OR guest mode is active.
final isLoggedInProvider = Provider<bool>((ref) {
  if (ref.watch(guestModeProvider)) return true;
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (isLoggedIn) => isLoggedIn) ?? false;
});

/// Returns guest profile in guest mode, otherwise fetches from Supabase.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  if (ref.watch(guestModeProvider)) return _guestProfile;

  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return null;

  final client = ref.watch(supabaseClientProvider);
  final authUser = client.auth.currentUser;
  if (authUser == null) return null;

  try {
    final repo = ref.watch(authRepositoryProvider);
    final profile = await repo.getProfile(authUser.id);
    // Use auth.users email if profile doesn't have one (e.g. legacy row)
    if (profile.email.isEmpty && authUser.email != null) {
      return profile.copyWith(email: authUser.email!);
    }
    return profile;
  } catch (e) {
    // Return a dummy profile with just the email so the UI doesn't crash on null
    return UserModel(
      id: authUser.id,
      email: authUser.email ?? 'No email',
      name: 'User',
      createdAt: DateTime.now(),
    );
  }
});

final hasTakenDiagnosticProvider = Provider<bool>((ref) {
  if (ref.watch(guestModeProvider)) return true;
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.hasTakenDiagnostic ?? false) ?? false;
});
