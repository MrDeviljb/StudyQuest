import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

class NotificationHelper {
  static Future<void> showStudyReminder({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      NotificationService.channelId,
      NotificationService.channelName,
      channelDescription: NotificationService.channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'StudyQuest Reminder',
      ),
      color: const Color(0xFF8B5CF6), // Purple accent color
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await NotificationService.plugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
