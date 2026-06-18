import 'package:flutter/material.dart';

/// User notification controls, mirroring the `notification_prefs` row
/// (Feature 1). Quiet hours + the per-day cap keep the engine from spamming —
/// muted OS channels are lost permanently, so these are not optional.
class NotificationPrefs {
  final bool enabled;
  final TimeOfDay quietStart;
  final TimeOfDay quietEnd;
  final int maxPerDay;

  /// Device UTC offset in minutes (so the engine applies quiet hours in the
  /// user's local time without a tz package). Null → engine uses UTC.
  final String? timezone;

  const NotificationPrefs({
    this.enabled = true,
    this.quietStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietEnd = const TimeOfDay(hour: 8, minute: 0),
    this.maxPerDay = 1,
    this.timezone,
  });

  static const NotificationPrefs defaults = NotificationPrefs();

  NotificationPrefs copyWith({
    bool? enabled,
    TimeOfDay? quietStart,
    TimeOfDay? quietEnd,
    int? maxPerDay,
    String? timezone,
  }) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        maxPerDay: maxPerDay ?? this.maxPerDay,
        timezone: timezone ?? this.timezone,
      );

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        enabled: j['enabled'] as bool? ?? true,
        quietStart: _parseTime(j['quiet_start'] as String?) ??
            const TimeOfDay(hour: 22, minute: 0),
        quietEnd: _parseTime(j['quiet_end'] as String?) ??
            const TimeOfDay(hour: 8, minute: 0),
        maxPerDay: j['max_per_day'] as int? ?? 1,
        timezone: j['timezone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'quiet_start': _fmt(quietStart),
        'quiet_end': _fmt(quietEnd),
        'max_per_day': maxPerDay,
        'timezone': timezone,
      };

  String quietRangeLabel(BuildContext context) =>
      '${quietStart.format(context)} – ${quietEnd.format(context)}';

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  static TimeOfDay? _parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
