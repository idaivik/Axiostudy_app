import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Best-effort: prepare local notifications (skip-practice reminders).
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: AxioStudyApp(),
    ),
  );
}
