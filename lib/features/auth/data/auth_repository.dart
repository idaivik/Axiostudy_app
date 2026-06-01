import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_model.dart';

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

  /// Sign out the current user.
  Future<void> signOut() async {
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
