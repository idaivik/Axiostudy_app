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
  // De-duplicate: token-refresh and other no-op events fire onAuthStateChange
  // repeatedly with the same session state, causing currentUserProvider to
  // re-run in a loop. Only emit when the signed-in boolean actually changes.
  bool? last;
  return client.auth.onAuthStateChange
      .map((authState) => authState.session != null)
      .where((isLoggedIn) {
        if (isLoggedIn == last) return false;
        last = isLoggedIn;
        return true;
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
    // Guard against a hung request leaving the router stuck on the splash gate.
    final profile = await repo
        .getProfile(authUser.id)
        .timeout(const Duration(seconds: 12));
    // Use auth.users email if profile doesn't have one (e.g. legacy row)
    if (profile.email.isEmpty && authUser.email != null) {
      return profile.copyWith(email: authUser.email!);
    }
    return profile;
  } catch (e) {
    // On any error (network, timeout, missing row) return null so the router
    // guard falls through to /login rather than returning a dummy profile with
    // default fields (no examType, no subscription) which confuses the
    // onboarding gate and causes an infinite exam→paywall redirect loop.
    return null;
  }
});

final hasTakenDiagnosticProvider = Provider<bool>((ref) {
  if (ref.watch(guestModeProvider)) return true;
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.hasTakenDiagnostic ?? false) ?? false;
});
