class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://nxtfbyvacunsiytlsfkl.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im54dGZieXZhY3Vuc2l5dGxzZmtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM0ODUwNzgsImV4cCI6MjA4OTA2MTA3OH0.DojA5driPSrZYoOsGJTM_hcvL_EX0uxIYxuLiHuhYU8';

  /// Deep link that Supabase auth emails (email confirmation, password reset)
  /// redirect back to. Opens the app instead of a dead `localhost` page.
  ///
  /// Must match, exactly:
  ///   • Supabase Dashboard → Authentication → URL Configuration → Redirect URLs
  ///   • the Android intent-filter in AndroidManifest.xml
  ///   • the CFBundleURLSchemes entry in ios/Runner/Info.plist
  static const String authRedirectUrl = 'com.axiostudy.app://login-callback';
}
