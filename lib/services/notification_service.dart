import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Handles local notifications for booking confirmations and session reminders.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin. Call once at app start.
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Show an immediate notification (e.g., booking confirmation).
  Future<void> showBookingConfirmation({
    required String consultationId,
    required String expertName,
    required String sessionType,
    required DateTime scheduledAt,
  }) async {
    if (!_initialized) return;

    final id = consultationId.hashCode.abs() % 100000;
    final timeStr = '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}';

    await _plugin.show(
      id,
      'Booking Confirmed!',
      '$sessionType session with $expertName on $dateStr at $timeStr',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bookings',
          'Booking Notifications',
          channelDescription: 'Notifications for consultation bookings',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule a reminder 10 minutes before the session.
  Future<void> scheduleSessionReminder({
    required String consultationId,
    required String expertName,
    required String sessionType,
    required DateTime scheduledAt,
  }) async {
    if (!_initialized) return;

    final reminderTime = scheduledAt.subtract(const Duration(minutes: 10));

    // Don't schedule if the reminder time is already past
    if (reminderTime.isBefore(DateTime.now())) return;

    final id = (consultationId.hashCode.abs() % 100000) + 1;

    try {
      await _plugin.zonedSchedule(
        id,
        'Session Starting Soon!',
        'Your $sessionType session with $expertName starts in 10 minutes',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'Session Reminders',
            channelDescription: 'Reminders before consultation sessions',
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  /// Cancel a scheduled reminder.
  Future<void> cancelReminder(String consultationId) async {
    if (!_initialized) return;
    final id = (consultationId.hashCode.abs() % 100000) + 1;
    await _plugin.cancel(id);
  }
}
