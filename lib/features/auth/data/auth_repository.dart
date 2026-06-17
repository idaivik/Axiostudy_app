import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/billing/revenuecat.dart';
import '../../../shared/models/enums.dart';
import '../domain/user_model.dart';

/// Thrown when signup succeeds but the account still needs email confirmation
/// before a session can be established (Supabase "Confirm email" enabled).
class EmailConfirmationRequired implements Exception {
  final String email;
  const EmailConfirmationRequired(this.email);
  @override
  String toString() => 'Email confirmation required for $email';
}

/// Repository for Supabase Auth and profile operations.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Sign in with email and password.
  Future<UserModel> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Login failed: no user returned');
    }

    return await getProfile(response.user!.id);
  }

  /// Create a new account with email + password. The `name` is forwarded as
  /// user metadata so the `handle_new_user` trigger names the profile row.
  ///
  /// Returns the new user's id. If the project requires email confirmation no
  /// session is created and [EmailConfirmationRequired] is thrown so the UI can
  /// prompt the user. When confirmation is disabled, the returned session is
  /// already active and the caller can proceed straight into onboarding.
  Future<String> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name.trim()},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Sign up failed: no user returned');
    }

    // Confirmation disabled -> session is live immediately.
    if (response.session != null) return user.id;

    // No session: either confirmation is required, or this was a re-signup of
    // an existing account. Try a direct sign-in to recover a session.
    try {
      final signIn = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (signIn.session != null) return signIn.user!.id;
    } on AuthException {
      // fall through to confirmation prompt
    }
    throw EmailConfirmationRequired(email);
  }

  /// Persist the user's chosen target exam (JEE / NEET).
  Future<void> setExamType(String userId, ExamType examType) async {
    await _client
        .from('profiles')
        .update({'exam_type': examType.name})
        .eq('id', userId);
  }

  /// Persist the entitlement returned by a store purchase / restore. Writes only
  /// the subscription columns so other profile fields are left untouched. The
  /// RevenueCat webhook is the long-term source of truth; this is the optimistic
  /// client-side write that clears the paywall right after purchase.
  Future<void> activateSubscription(
    String userId, {
    required SubscriptionTier tier,
    required SubscriptionStatus status,
    DateTime? trialEndsAt,
    required DateTime subscriptionExpiry,
    String? platform,
    String? storeProductId,
    String? storeTransactionId,
  }) async {
    await _client.from('profiles').update({
      'subscription_tier': tier.name,
      'subscription_status': status.dbValue,
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'subscription_expiry': subscriptionExpiry.toIso8601String(),
      'subscription_platform': platform,
      'store_product_id': storeProductId,
      'store_transaction_id': storeTransactionId,
    }).eq('id', userId);
  }

  /// Mark AI profiling / onboarding as finished — the final gate before the app.
  /// Optionally persists profiling answers (e.g. [grade]) collected on the way.
  Future<void> completeOnboarding(String userId, {String? grade}) async {
    final update = <String, dynamic>{'onboarding_completed': true};
    if (grade != null) update['grade'] = grade;
    await _client.from('profiles').update(update).eq('id', userId);
  }

  /// Sign out the current user. Also detaches RevenueCat so a subsequent login
  /// on the same device doesn't inherit this user's entitlements.
  Future<void> signOut() async {
    await RevenueCat.logoutBestEffort();
    await _client.auth.signOut();
  }

  /// Get the profile for a given user ID.
  Future<UserModel> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(data);
  }

  /// Update the user's profile.
  Future<void> updateProfile(UserModel user) async {
    await _client
        .from('profiles')
        .update(user.toJson())
        .eq('id', user.id);
  }

  /// Get the currently authenticated user (or null).
  User? get currentAuthUser => _client.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
