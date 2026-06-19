import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder_model.dart';
import '../utils/reminder_utils.dart';
import 'notification_background_handler.dart';
import 'reminder_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ReminderService _reminderService = ReminderService();

  Function(String?)? _onForeground;
  bool _initialized = false;

  Future<void> init({required Function(String?) onForeground}) async {
    if (_initialized) {
      _onForeground = onForeground;
      return;
    }
    _onForeground = onForeground;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iOS = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'REMINDER_ACTIONS',
          actions: [
            DarwinNotificationAction.plain('COMPLETE_ACTION', 'Complete'),
            DarwinNotificationAction.plain('SNOOZE_ACTION', 'Snooze'),
            DarwinNotificationAction.plain('STOP_ACTION', 'Stop'),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundTapHandler,
    );

    await Permission.scheduleExactAlarm.request();
    await Permission.notification.request();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _initialized = true;
  }

  /// Returns launch payload when the app was opened from a notification tap.
  Future<String?> consumeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final response = details!.notificationResponse;
    if (response == null) return null;
    final actionId = response.actionId ?? 'OPEN_ACTION';
    final payload = response.payload ?? '';
    if (payload.isEmpty) return null;
    return '$actionId|$payload';
  }

  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId ?? 'OPEN_ACTION';
    final payload = response.payload ?? '';
    debugPrint('[NOTIF] FG response: $actionId | $payload');
    if (payload.isEmpty) return;
    _onForeground?.call('$actionId|$payload');
  }

  NotificationDetails _buildDetails(Reminder reminder) {
    final isRingtone =
        reminder.notificationMode == ReminderNotificationMode.ringtone;

    final android = AndroidNotificationDetails(
      'reminder_alarm_channel',
      'Reminder Alerts',
      channelDescription: 'Reminder notifications with alarm sound',
      importance: Importance.max,
      priority: Priority.high,
      playSound: isRingtone,
      sound: isRingtone
          ? const RawResourceAndroidNotificationSound('alarm')
          : null,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      actions: const [
        AndroidNotificationAction(
          'COMPLETE_ACTION',
          'Complete',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'SNOOZE_ACTION',
          'Snooze',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'STOP_ACTION',
          'Stop',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final darwin = DarwinNotificationDetails(
      categoryIdentifier: 'REMINDER_ACTIONS',
      sound: isRingtone ? 'alarm.mp3' : null,
      presentAlert: true,
      presentSound: isRingtone,
    );

    return NotificationDetails(android: android, iOS: darwin);
  }

  Future<void> scheduleReminder({
    required Reminder reminder,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    debugPrint('SCHEDULE: ${reminder.title} at $scheduledDate → $tzDate');

    await _plugin.zonedSchedule(
      reminder.id.hashCode,
      reminder.title,
      reminder.description.isEmpty ? 'Reminder!' : reminder.description,
      tzDate,
      _buildDetails(reminder),
      payload: payload ?? reminder.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    // Primary hook: Dart timer fires handleReminderNotification at reminder time.
    _reminderService.armReminderTrigger(reminder, scheduledDate);
  }

  Future<void> showImmediateReminder(Reminder reminder,
      {String? payload}) async {
    await _plugin.show(
      reminder.id.hashCode,
      reminder.title,
      reminder.description.isEmpty ? 'Reminder!' : reminder.description,
      _buildDetails(reminder),
      payload: payload ?? reminder.id,
    );

    await _reminderService.handleReminderNotification(reminder);
  }

  Future<void> cancelById(String id) async {
    _reminderService.disarmReminderTrigger(id);
    await _plugin.cancel(id.hashCode);
  }

  Future<void> cancelAll() async {
    _reminderService.disarmAllTriggers();
    await _plugin.cancelAll();
  }

  Future<void> testNotification() async {
    await _plugin.show(
      999,
      'Test Notification',
      'Notifications are working!',
      _buildDetails(
        Reminder(
          id: 'test',
          userId: '',
          title: 'Test',
          description: '',
          type: ReminderType.daily,
          startTime: '09:00',
          endTime: '18:00',
          activeDateZone: ReminderActiveDateZone.daily,
          selectedDays: const [],
          priority: ReminderPriority.medium,
          category: ReminderCategory.personal,
          maxSnoozeCount: 3,
          currentSnoozeCount: 0,
          snoozeIntervalMinutes: 10,
          status: ReminderStatus.pending,
          reminderTime: DateTime.now(),
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }
}
