import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/billing/revenuecat.dart';
import 'core/supabase/supabase_config.dart';
import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize store billing (no-op until a RevenueCat key is configured).
  await RevenueCat.init();
  // Attribute purchases to an already-signed-in user (purchases also identify
  // just-in-time, so this only matters for a returning session on launch).
  final existingUser = Supabase.instance.client.auth.currentUser;
  if (existingUser != null) await RevenueCat.identify(existingUser.id);

  // Best-effort: prepare local notifications (skip-practice reminders).
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: AxioStudyApp(),
    ),
  );
}
