import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  subscriptionTier: SubscriptionTier.pro,
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

/// True while the user is in a password-recovery session (arrived via a
/// reset-password deep link). The router gives this precedence and routes them
/// to the set-new-password screen until they finish or sign out.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// Subscribes to Supabase auth events and flips [passwordRecoveryProvider] when
/// a password-recovery deep link is opened. Kept alive by the router watching
/// it, so the subscription lives for the whole app session.
final authEventListenerProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final sub = client.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    }
  });
  ref.onDispose(sub.cancel);
});

/// Fires on every Supabase auth event (sign-in/out, token refresh, recovery).
///
/// Intentionally just a *change trigger* — consumers below read the real
/// session / `currentUser` rather than a value carried on the event. We emit
/// the raw [AuthState] (a distinct value per event) so state-derived providers
/// re-evaluate on every event.
///
/// A previous version mapped this to a `session != null` bool and de-duplicated
/// consecutive equal values. That could *swallow* the `signedIn` event right
/// after login, leaving the app reactively "logged out" while a valid session
/// existed — which bounced the user back to /login in an endless loop even
/// though both the token and profile requests returned 200.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Logged in if a Supabase session exists OR guest mode is active.
///
/// Recomputes on every auth event but trusts the actual persisted session as
/// the source of truth: `onAuthStateChange` can deliver a frame *after*
/// `signInWithPassword` has already set `currentSession`, so reading the session
/// directly avoids a stale "logged out" read. Token-refresh events recompute to
/// the same bool, so dependents aren't needlessly rebuilt.
final isLoggedInProvider = Provider<bool>((ref) {
  if (ref.watch(guestModeProvider)) return true;
  ref.watch(authStateProvider); // re-evaluate whenever auth state changes
  return ref.watch(supabaseClientProvider).auth.currentSession != null;
});

/// Returns guest profile in guest mode, otherwise fetches from Supabase.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  if (ref.watch(guestModeProvider)) return _guestProfile;

  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return null;

  final client = ref.watch(supabaseClientProvider);
  final authUser = client.auth.currentUser;
  if (authUser == null) return null;

  final repo = ref.watch(authRepositoryProvider);
  // Retry a few times before giving up: a transient network blip or a session
  // that hasn't fully settled right after sign-in shouldn't resolve to null,
  // because the router treats a null profile as "couldn't load" and keeps the
  // user on the splash gate.
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      // Guard against a hung request leaving the router stuck on the splash gate.
      final profile = await repo
          .getProfile(authUser.id)
          .timeout(const Duration(seconds: 12));
      // Use auth.users email if profile doesn't have one (e.g. legacy row)
      if (profile.email.isEmpty && authUser.email != null) {
        return profile.copyWith(email: authUser.email!);
      }
      return profile;
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
  // Exhausted retries. Return null so the router guard can react — it holds an
  // authenticated user on /splash (not /login, which would loop) and a later
  // refresh re-attempts the load. A dummy default profile is deliberately not
  // returned: it has no examType/subscription and would confuse the onboarding
  // gate into an exam→paywall redirect loop.
  return null;
});

final hasTakenDiagnosticProvider = Provider<bool>((ref) {
  if (ref.watch(guestModeProvider)) return true;
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.hasTakenDiagnostic ?? false) ?? false;
});
