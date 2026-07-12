import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'task_model.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;

  static const String channelId = 'study_alarm_channel_v1';
  static const String channelName = 'StudyQuest Alarms';
  static const String channelDesc = 'High importance alarms for scheduled study sessions';

  // Stream controller to notify the UI when an alarm action is triggered
  static Function(String action, String taskId)? onAlarmActionTriggered;

  static Future<void> init() async {
    // 1. Initialize Timezones
    tz.initializeTimeZones();

    // 2. Configure Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 3. Initialize plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // 4. Create Alarm Notification Channel with Custom Sound & Vibration
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alarm_tone'),
          enableVibration: true,
          vibrationPattern: [0, 1000, 500, 2000, 500, 3000],
        ));
  }

  // Handle actions clicked inside notifications when app is in foreground/background
  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId; // 'start_study', 'snooze', 'complete', 'skip'
    
    if (payload != null && actionId != null) {
      final data = jsonDecode(payload);
      final taskId = data['id'] as String;
      onAlarmActionTriggered?.call(actionId, taskId);
    }
  }

  // Background action handler
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Handle actions when app is fully closed.
    // In production, you'd write state modifications directly to Hive from here
    // since providers are not running in background isolates.
    final payload = response.payload;
    final actionId = response.actionId;
    if (payload != null && actionId != null) {
      // Background notifications logic goes here if needed.
    }
  }

  // Request permissions for Android 13+
  static Future<bool> requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    final grantedNotifications = await androidImplementation?.requestNotificationsPermission() ?? false;
    final grantedAlarm = await androidImplementation?.requestExactAlarmsPermission() ?? false;

    return grantedNotifications && grantedAlarm;
  }

  // Schedule alarm for a task
  static Future<void> scheduleAlarm(Task task) async {
    if (task.reminderMinutesBefore == null || task.completed) return;

    final targetDateTime = _calculateAlarmTime(task);
    if (targetDateTime.isBefore(DateTime.now())) return; // skip if past

    final tzDateTime = tz.TZDateTime.from(targetDateTime, tz.local);
    final notificationId = task.id.hashCode;

    final payload = jsonEncode({
      'id': task.id,
      'title': task.title,
      'subject': task.subject,
      'startTime': task.startTime,
      'colorHex': task.colorHex,
    });

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_tone'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 2000, 500, 3000]),
      fullScreenIntent: true, // Wake up screen & trigger alarm overlay
      category: AndroidNotificationCategory.alarm,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'start_study',
          'Start Study',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze',
          'Snooze 10m',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'complete',
          'Complete',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'skip',
          'Skip',
          showsUserInterface: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    if (task.repeat == 'none') {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'StudyQuest Alarm: ${task.subject}',
        'Time to study: ${task.title}',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } else if (task.repeat == 'daily') {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'StudyQuest Daily Alarm: ${task.subject}',
        'Time to study: ${task.title}',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } else if (task.repeat == 'weekly') {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'StudyQuest Weekly Alarm: ${task.subject}',
        'Time to study: ${task.title}',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    }
  }

  // Cancel alarm for a task
  static Future<void> cancelAlarm(String taskId) async {
    await _notificationsPlugin.cancel(taskId.hashCode);
  }

  // Parse time and date from task into single DateTime object minus reminder minutes
  static DateTime _calculateAlarmTime(Task task) {
    int hour = 8;
    int minute = 0;

    if (task.startTime != null) {
      final timeStr = task.startTime!; // e.g. "09:00 AM" or "19:00"
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        // 12-hour format
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        final isPm = parts[1].toUpperCase() == 'PM';
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        // 24-hour format
        final timeParts = timeStr.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }
    }

    final taskDateTime = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
      hour,
      minute,
    );

    // Subtract reminder offset
    return taskDateTime.subtract(Duration(minutes: task.reminderMinutesBefore ?? 0));
  }
}
