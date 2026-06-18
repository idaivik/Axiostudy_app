import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase Cloud Messaging client for Feature 1's server-driven reminders.
///
/// Everything is guarded: until the Firebase project config files are added
/// (google-services.json / GoogleService-Info.plist — see REMINDERS_SETUP.md),
/// `Firebase.initializeApp()` throws and the service stays DORMANT — the app
/// builds and runs exactly as before, just without push. Once configured it:
///   • registers the device token in `user_devices` on login + refresh,
///   • re-registers on token rotation,
///   • clears the token on logout.
///
/// Permission is requested at a sensible moment (when the user enables reminders
/// in Settings), never cold on launch.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _available = false;
  bool _initStarted = false;

  SupabaseClient get _client => Supabase.instance.client;

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Best-effort init. No-op (and leaves push disabled) when Firebase isn't
  /// configured yet, so it's always safe to call from `main`.
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (_) {
      _available = false;
      return; // Firebase not configured → dormant.
    }

    try {
      FirebaseMessaging.instance.onTokenRefresh.listen(_upsertToken);
      _client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed) {
          registerCurrentToken();
        }
      });
      await registerCurrentToken();
    } catch (_) {/* best-effort */}
  }

  /// Ask for the OS push permission and register the token. Call this when the
  /// user opts into reminders.
  Future<void> requestPermissionAndRegister() async {
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      await registerCurrentToken();
    } catch (_) {/* best-effort */}
  }

  /// Upsert the current FCM token for the signed-in user (if any).
  Future<void> registerCurrentToken() async {
    if (!_available) return;
    if (_client.auth.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _upsertToken(token);
    } catch (_) {/* best-effort */}
  }

  /// Remove this device's token (call on logout, BEFORE signing out so the RLS
  /// delete is still authorized).
  Future<void> clearToken() async {
    if (!_available) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _client.from('user_devices').delete().eq('fcm_token', token);
      }
    } catch (_) {/* best-effort */}
  }

  Future<void> _upsertToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('user_devices').upsert({
        'fcm_token': token,
        'user_id': userId,
        'platform': _platform,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {/* best-effort */}
  }
}
