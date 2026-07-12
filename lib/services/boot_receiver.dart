import '../database/hive_service.dart';
import 'alarm_service.dart';

class BootReceiver {
  static Future<void> rescheduleAlarms() async {
    try {
      final tasks = HiveService.getAllTasks();
      for (var task in tasks) {
        if (!task.completed) {
          await AlarmService.scheduleAlarm(task);
        }
      }
    } catch (e) {
      // ignore
    }
  }
}
