import 'package:flutter/services.dart';
import '../database/models/task_model.dart';

class AlarmScheduler {
  static const MethodChannel _channel = MethodChannel('com.studyquest.studyquest/alarm');

  static Future<void> scheduleAlarm(Task task) async {
    final targetDateTime = calculateAlarmTime(task);
    final now = DateTime.now();

    // Adjust target time for repeating patterns if it's already in the past
    DateTime adjustedTarget = targetDateTime;
    if (adjustedTarget.isBefore(now)) {
      if (task.repeat == 'daily') {
        adjustedTarget = adjustedTarget.add(const Duration(days: 1));
      } else if (task.repeat == 'weekly') {
        adjustedTarget = adjustedTarget.add(const Duration(days: 7));
      } else if (task.repeat == 'monthly') {
        adjustedTarget = DateTime(
          adjustedTarget.year,
          adjustedTarget.month + 1,
          adjustedTarget.day,
          adjustedTarget.hour,
          adjustedTarget.minute,
        );
      } else {
        // Past non-repeating alarms are not scheduled
        return;
      }
    }

    final triggerTime = adjustedTarget.millisecondsSinceEpoch;

    try {
      await _channel.invokeMethod('scheduleExactAlarm', {
        'id': task.id,
        'title': task.title,
        'subject': task.subject,
        'time': task.startTime ?? '',
        'triggerTime': triggerTime,
      });
    } catch (e) {
      // ignore
    }
  }

  static Future<void> cancelAlarm(String taskId) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {
        'id': taskId,
      });
    } catch (e) {
      // ignore
    }
  }

  static DateTime calculateAlarmTime(Task task) {
    int hour = 8;
    int minute = 0;

    if (task.startTime != null) {
      final timeStr = task.startTime!;
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        final isPm = parts[1].toUpperCase() == 'PM';
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
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

    return taskDateTime.subtract(Duration(minutes: task.reminderMinutesBefore ?? 0));
  }
}
