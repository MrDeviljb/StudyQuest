import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static const MethodChannel _channel = MethodChannel('com.studyquest.studyquest/alarm');

  static Future<bool> requestAlarmPermissions() async {
    // 1. Post Notifications Permission (Android 13+)
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }

    // 2. Schedule Exact Alarm Permission (Android 12+)
    bool hasExactAlarm = await checkExactAlarmPermission();
    if (!hasExactAlarm) {
      await requestExactAlarmPermission();
    }

    // 3. Ignore Battery Optimizations (Android 6+)
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    final hasNotification = await Permission.notification.isGranted;
    hasExactAlarm = await checkExactAlarmPermission();
    final hasIgnoreBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    
    return hasNotification && hasExactAlarm && hasIgnoreBattery;
  }

  static Future<bool> checkPermissionStatus() async {
    final notificationStatus = await Permission.notification.isGranted;
    final exactStatus = await checkExactAlarmPermission();
    return notificationStatus && exactStatus;
  }

  static Future<bool> checkExactAlarmPermission() async {
    try {
      final bool result = await _channel.invokeMethod('checkExactAlarmPermission');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestExactAlarmPermission() async {
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      // ignore
    }
  }
}
