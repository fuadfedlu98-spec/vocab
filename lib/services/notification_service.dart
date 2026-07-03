import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../db/db_helper.dart';

/// Frequency options for the daily reminder.
enum ReminderFrequency { daily, twicePerDay }

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'vocab_reminder_channel';
  static const String _channelName = 'Vocabulary Reminders';
  static const String _channelDesc =
      'Daily reminders to review your vocabulary words';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    // Uses the device's local timezone offset.
    tz.setLocalLocation(tz.getLocation(await _deviceTimeZoneName()));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<String> _deviceTimeZoneName() async {
    // Fallback to UTC if the platform timezone cannot be resolved;
    // scheduling still works using device local time via matchDateTimeComponents.
    try {
      return DateTime.now().timeZoneName.isNotEmpty
          ? tz.local.name
          : 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Schedules a repeating daily reminder at [hour]:[minute].
  /// If [frequency] is twicePerDay, also schedules a second reminder
  /// 12 hours later (simple implementation, still using the device scheduler).
  Future<void> scheduleReminder({
    required int hour,
    required int minute,
    required ReminderFrequency frequency,
  }) async {
    await init();
    await cancelAll();

    await _scheduleDaily(id: 0, hour: hour, minute: minute);

    if (frequency == ReminderFrequency.twicePerDay) {
      final secondHour = (hour + 12) % 24;
      await _scheduleDaily(id: 1, hour: secondHour, minute: minute);
    }

    await DBHelper.instance.setSetting('reminder_hour', hour.toString());
    await DBHelper.instance.setSetting('reminder_minute', minute.toString());
    await DBHelper.instance
        .setSetting('reminder_frequency', frequency.name);
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      'Vocabulary Review',
      'Time to review your vocabulary',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Reloads saved settings and re-applies the schedule.
  /// Call this on app startup so reminders stay correct.
  Future<void> restoreSchedule() async {
    final hourStr = await DBHelper.instance.getSetting('reminder_hour');
    final minuteStr = await DBHelper.instance.getSetting('reminder_minute');
    final freqStr = await DBHelper.instance.getSetting('reminder_frequency');

    if (hourStr == null || minuteStr == null) return;

    final frequency = freqStr == ReminderFrequency.twicePerDay.name
        ? ReminderFrequency.twicePerDay
        : ReminderFrequency.daily;

    await scheduleReminder(
      hour: int.parse(hourStr),
      minute: int.parse(minuteStr),
      frequency: frequency,
    );
  }
}
