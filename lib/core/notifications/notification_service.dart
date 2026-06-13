import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local (OS-level) notifications — no Firebase, no server (Phase 4).
///
/// The only reminder today: when a student finishes a test with weak chapters
/// but doesn't practice, fire a gentle nudge 24h later. Scheduling it replaces
/// any pending one (same id); starting a practice session cancels it.
///
/// Everything is best-effort and guarded — notifications are a nicety, never a
/// crash surface, so platforms without the plugin configured just no-op.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _practiceReminderId = 1001;
  static const String _channelId = 'practice_reminders';

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Ask for notification permission (Android 13+ / iOS). Best-effort.
  Future<void> requestPermission() async {
    try {
      await init();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {/* best-effort */}
  }

  /// Schedule the "you skipped practice" nudge for [after] from now (24h).
  Future<void> schedulePracticeReminder({
    Duration after = const Duration(hours: 24),
  }) async {
    try {
      await init();
      if (!_ready) return;
      final when = tz.TZDateTime.now(tz.local).add(after);
      await _plugin.zonedSchedule(
        _practiceReminderId,
        'Keep your momentum 📈',
        "You've got weak chapters waiting — a quick AI practice set today keeps "
            'your scores climbing.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Practice reminders',
            channelDescription: 'Reminds you to practice your weak chapters',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {/* best-effort */}
  }

  Future<void> cancelPracticeReminder() async {
    try {
      await _plugin.cancel(_practiceReminderId);
    } catch (_) {/* best-effort */}
  }
}
