import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/billing/revenuecat.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/supabase/supabase_config.dart';
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

/// Thrown on login when the account exists but its email has not been verified
/// yet. The UI surfaces a clear message and offers to resend the link.
class EmailNotConfirmedException implements Exception {
  final String email;
  const EmailNotConfirmedException(this.email);
  @override
  String toString() => 'Email not confirmed for $email';
}

/// Thrown when an authenticated user has no matching `profiles` row and one
/// could not be created. Signals the UI to show a real error instead of
/// silently bouncing back to the login screen.
class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException();
  @override
  String toString() => 'Profile row not found for the signed-in user';
}

/// Repository for Supabase Auth and profile operations.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Sign in with email and password.
  ///
  /// Translates Supabase's stringly-typed "Email not confirmed" auth error into
  /// a typed [EmailNotConfirmedException] so the UI can show a clear message and
  /// offer to resend the verification email.
  Future<UserModel> signInWithEmail(String email, String password) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      if (_isEmailNotConfirmed(e)) {
        throw EmailNotConfirmedException(email);
      }
      rethrow;
    }

    if (response.user == null) {
      throw Exception('Login failed: no user returned');
    }

    return await getProfile(response.user!.id);
  }

  /// True when an [AuthException] is Supabase's "email not confirmed" rejection.
  bool _isEmailNotConfirmed(AuthException e) {
    final msg = e.message.toLowerCase();
    return e.code == 'email_not_confirmed' ||
        msg.contains('email not confirmed') ||
        msg.contains('not confirmed');
  }

  /// Re-send the signup confirmation email (with the deep-link redirect) so a
  /// user who lost or never received the first one can verify their address.
  Future<void> resendConfirmationEmail(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  /// Send a password-reset email. The link redirects back into the app via the
  /// auth deep link, where supabase_flutter raises an
  /// [AuthChangeEvent.passwordRecovery] event and the router shows the
  /// set-new-password screen.
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  /// Set a new password for the user in the active (recovery) session.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
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
      // After the user taps the link in the confirmation email, Supabase
      // redirects here — a deep link that re-opens the app and lets
      // supabase_flutter establish the session automatically.
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
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

  /// Opt the user in/out of early-access (Bucket 2 §3c). Writes only the one
  /// column so the rest of the profile is untouched.
  Future<void> setEarlyAccess(String userId, bool enabled) async {
    await _client
        .from('profiles')
        .update({'early_access': enabled})
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
    // Clear the device's push token BEFORE signing out, while the RLS delete is
    // still authorized, so the next user on this device doesn't inherit it.
    await FcmService.instance.clearToken();
    await RevenueCat.logoutBestEffort();
    await _client.auth.signOut();
  }

  /// Get the profile for a given user ID.
  ///
  /// The `handle_new_user` trigger normally creates this row at signup. If it is
  /// ever missing (trigger failure, a legacy account, or a row deleted out of
  /// band) we self-heal by inserting a minimal row from the auth user, rather
  /// than throwing — which previously left the router bouncing the user back to
  /// `/login` after a successful password sign-in.
  Future<UserModel> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data != null) return UserModel.fromJson(data);

    // No row — try to recreate it from the authenticated user.
    final authUser = _client.auth.currentUser;
    if (authUser == null || authUser.id != userId) {
      throw const ProfileNotFoundException();
    }
    final name = (authUser.userMetadata?['name'] as String?)?.trim();
    final inserted = await _client
        .from('profiles')
        .insert({
          'id': userId,
          'email': authUser.email,
          if (name != null && name.isNotEmpty) 'name': name,
        })
        .select()
        .single();
    return UserModel.fromJson(inserted);
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
