import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../main.dart';
import '../screens/alarm_screen.dart';
import 'alarm_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;

  static const String channelId = 'studyquest_alarm_channel_v2';
  static const String channelName = 'StudyQuest Alarm Alerts';
  static const String channelDesc = 'High urgency full-screen alarm notification alerts';

  static const MethodChannel _channel = MethodChannel('com.studyquest.studyquest/alarm');

  static final StreamController<String> _payloadStreamController =
      StreamController<String>.broadcast();

  static Stream<String> get onNotificationTriggered => _payloadStreamController.stream;

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Resolve android platform implementation and create notification channel
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alarm_tone'),
          enableVibration: true,
        ));

    // Register MethodChannel callback handler to listen to Android native alarms
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      _payloadStreamController.add(response.payload!);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Kept empty to prevent background thread isolates crash
  }

  static Future<void> checkRingingStateOnLaunch() async {
    try {
      final activeAlarm = await _channel.invokeMethod('getActiveAlarm');
      if (activeAlarm != null) {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(activeAlarm);
        _openAlarmScreen(payload);
      }
    } catch (e) {
      debugPrint("Error checking active alarm on launch: $e");
    }

    try {
      final actionData = await _channel.invokeMethod('consumeAlarmAction');
      if (actionData != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(actionData);
        _handleAlarmAction(data['action'], data['task_id']);
      }
    } catch (e) {
      debugPrint("Error consuming alarm action: $e");
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlarmRinging':
        final Map<String, dynamic> payload = Map<String, dynamic>.from(call.arguments);
        _openAlarmScreen(payload);
        break;
      case 'onAlarmAction':
        final String action = call.arguments['action'];
        final String taskId = call.arguments['task_id'];
        _handleAlarmAction(action, taskId);
        break;
    }
  }

  static void _openAlarmScreen(Map<String, dynamic> payload) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(alarmPayload: payload),
      ),
    );
  }

  static void _handleAlarmAction(String action, String taskId) async {
    if (action == 'dismiss') {
      await AlarmService.dismissActiveAlarmWithId(taskId);
    } else if (action == 'snooze') {
      await AlarmService.snoozeActiveAlarmWithId(taskId, 10);
    }
  }

  static Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    return await _notificationsPlugin.getNotificationAppLaunchDetails();
  }
}
