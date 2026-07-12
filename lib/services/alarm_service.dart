import 'package:flutter/services.dart';
import '../database/models/task_model.dart';
import 'notification_service.dart';
import 'alarm_scheduler.dart';
import 'permission_manager.dart';
import 'alarm_repository.dart';

class AlarmService {
  static const MethodChannel _channel = MethodChannel('com.studyquest.studyquest/alarm');
  static bool _isAlarmActive = false;
  static Task? _activeTask;

  static bool get isAlarmActive => _isAlarmActive;
  static Task? get activeTask => _activeTask;

  static Future<void> init() async {
    await NotificationService.init();
  }

  static Future<bool> requestPermissions() async {
    return await PermissionManager.requestAlarmPermissions();
  }

  static Future<void> scheduleAlarm(Task task) async {
    if (!AlarmRepository.isAlarmEnabled()) return;
    await AlarmScheduler.scheduleAlarm(task);
  }

  static Future<void> cancelAlarm(String taskId) async {
    await AlarmScheduler.cancelAlarm(taskId);
  }

  // Called when AlarmScreen initializes to synchronize local state
  static Future<void> startAlarm(Task task) async {
    _isAlarmActive = true;
    _activeTask = task;
  }

  // Stops ringing sound and vibration pattern in Kotlin service
  static Future<void> stopAlarm() async {
    _isAlarmActive = false;
    _activeTask = null;
    try {
      await _channel.invokeMethod('stopAlarm');
    } catch (e) {
      // ignore
    }
  }

  // Dismiss by active task
  static Future<void> dismissActiveAlarm() async {
    if (_activeTask != null) {
      await dismissActiveAlarmWithId(_activeTask!.id);
    }
  }

  // Dismiss by ID
  static Future<void> dismissActiveAlarmWithId(String taskId) async {
    // 1. Stop native ringing/vibration
    await stopAlarm();

    // 2. Add history log
    await AlarmRepository.addHistoryEntry(AlarmHistoryEntry(
      taskId: taskId,
      taskTitle: _activeTask?.title ?? 'Study Session',
      subject: _activeTask?.subject ?? 'General Study',
      status: 'Dismissed',
      timestamp: DateTime.now(),
    ));

    // 3. Reschedule weekly repeating patterns if task object exists
    if (_activeTask != null && _activeTask!.repeat == 'weekly') {
      final nextWeekTask = _activeTask!.copyWith(
        date: _activeTask!.date.add(const Duration(days: 7)),
      );
      await AlarmScheduler.scheduleAlarm(nextWeekTask);
    }
  }

  // Snooze by active task
  static Future<void> snoozeActiveAlarm(int minutes) async {
    if (_activeTask != null) {
      await snoozeActiveAlarmWithId(_activeTask!.id, minutes);
    }
  }

  // Snooze by ID
  static Future<void> snoozeActiveAlarmWithId(String taskId, int minutes) async {
    final task = _activeTask;
    await stopAlarm();

    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final hour = snoozeTime.hour;
    final minute = snoozeTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute < 10 ? '0$minute' : '$minute';
    final startTimeStr = '$displayHour:$minuteStr $amPm';

    final snoozedTask = (task ?? Task(
      id: taskId,
      title: 'Snoozed Session',
      description: '',
      subject: 'General Study',
      date: DateTime.now(),
      priority: 1,
      repeat: 'none',
      xpReward: 50,
      coinReward: 20,
      notes: '',
      colorHex: '#8B5CF6',
      category: 'Study Session',
    )).copyWith(
      date: DateTime(snoozeTime.year, snoozeTime.month, snoozeTime.day),
      startTime: startTimeStr,
      reminderMinutesBefore: 0,
    );

    // Schedule exact snooze alarm
    await AlarmScheduler.scheduleAlarm(snoozedTask);

    await AlarmRepository.addHistoryEntry(AlarmHistoryEntry(
      taskId: taskId,
      taskTitle: snoozedTask.title,
      subject: snoozedTask.subject,
      status: 'Snoozed',
      timestamp: DateTime.now(),
    ));
  }

  // Complete by active task
  static Future<void> completeActiveAlarm(Function(int, int) onRewardAwarded) async {
    if (_activeTask != null) {
      await completeActiveAlarmWithId(_activeTask!.id, onRewardAwarded);
    }
  }

  // Complete by ID
  static Future<void> completeActiveAlarmWithId(String taskId, Function(int, int) onRewardAwarded) async {
    final task = _activeTask;
    await stopAlarm();

    await AlarmRepository.addHistoryEntry(AlarmHistoryEntry(
      taskId: taskId,
      taskTitle: task?.title ?? 'Study Session',
      subject: task?.subject ?? 'General Study',
      status: 'Completed',
      timestamp: DateTime.now(),
    ));

    final xp = task?.xpReward ?? 50;
    final coins = task?.coinReward ?? 20;
    onRewardAwarded(xp, coins);
  }
}
