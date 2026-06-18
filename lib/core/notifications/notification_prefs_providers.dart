import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import 'notification_prefs.dart';

/// Reads/writes the current user's `notification_prefs` row (Feature 1).
class NotificationPrefsRepository {
  final SupabaseClient _client;
  NotificationPrefsRepository(this._client);

  /// The signed-in user's prefs, or [NotificationPrefs.defaults] when there's no
  /// row yet (the engine treats a missing row as the same defaults).
  Future<NotificationPrefs> load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return NotificationPrefs.defaults;
    try {
      final row = await _client
          .from('notification_prefs')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null
          ? NotificationPrefs.defaults
          : NotificationPrefs.fromJson(row);
    } catch (_) {
      return NotificationPrefs.defaults;
    }
  }

  /// Upsert the prefs, stamping the device's current UTC offset so the engine
  /// applies quiet hours in local time.
  Future<void> save(NotificationPrefs prefs) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final offset = DateTime.now().timeZoneOffset.inMinutes.toString();
    await _client.from('notification_prefs').upsert({
      'user_id': userId,
      ...prefs.copyWith(timezone: offset).toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>((ref) {
  return NotificationPrefsRepository(ref.watch(supabaseClientProvider));
});

/// The current user's notification prefs (defaults until loaded/!signed-in).
final notificationPrefsProvider =
    FutureProvider<NotificationPrefs>((ref) async {
  return ref.watch(notificationPrefsRepositoryProvider).load();
});
