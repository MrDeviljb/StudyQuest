import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestAlarmPermissions() async {
    // 1. Post Notifications Permission (Android 13+)
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }

    // 2. Schedule Exact Alarm Permission (Android 12+)
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!alarmStatus.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }

    final hasNotification = await Permission.notification.isGranted;
    final hasExactAlarm = await Permission.scheduleExactAlarm.isGranted;
    
    return hasNotification && hasExactAlarm;
  }

  static Future<bool> checkPermissionStatus() async {
    final notificationStatus = await Permission.notification.isGranted;
    final alarmStatus = await Permission.scheduleExactAlarm.isGranted;
    return notificationStatus && alarmStatus;
  }
}
