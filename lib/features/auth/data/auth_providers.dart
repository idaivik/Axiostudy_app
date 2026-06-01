import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/user_model.dart';
import 'auth_repository.dart';

/// Provides the AuthRepository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Reactive auth state — emits true/false based on Supabase session.
final authStateProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return client.auth.onAuthStateChange.map((authState) {
    return authState.session != null;
  });
});

/// Whether the user is currently logged in (sync check).
final isLoggedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (isLoggedIn) => isLoggedIn) ?? false;
});

/// Current user profile — fetches from Supabase `profiles` table.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return null;

  final client = ref.watch(supabaseClientProvider);
  final authUser = client.auth.currentUser;
  if (authUser == null) return null;

  try {
    final repo = ref.watch(authRepositoryProvider);
    return await repo.getProfile(authUser.id);
  } catch (e) {
    return null;
  }
});

/// Whether the user has taken the diagnostic test.
final hasTakenDiagnosticProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.hasTakenDiagnostic ?? false) ?? false;
});
