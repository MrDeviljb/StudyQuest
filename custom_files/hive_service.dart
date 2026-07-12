import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'task_model.dart';
import 'profile_model.dart';

class HiveService {
  static const String tasksBoxName = 'tasks';
  static const String profileBoxName = 'profile';
  static const String settingsBoxName = 'settings';
  static const String statsBoxName = 'stats'; // Store daily study durations, etc.

  static late Box<Task> tasksBox;
  static late Box<UserProfile> profileBox;
  static late Box<dynamic> settingsBox;
  static late Box<dynamic> statsBox;

  static Future<void> init() async {
    // 1. Initialize Hive with the app directory path
    final Directory directory = await getApplicationDocumentsDirectory();
    Hive.init(directory.path);

    // 2. Register Manual Adapters
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserProfileAdapter());

    // 3. Open Boxes
    tasksBox = await Hive.openBox<Task>(tasksBoxName);
    profileBox = await Hive.openBox<UserProfile>(profileBoxName);
    settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
    statsBox = await Hive.openBox<dynamic>(statsBoxName);

    // 4. Initialize default user profile if none exists (first launch)
    if (profileBox.isEmpty) {
      final defaultProfile = UserProfile(
        name: 'Dev',
        unlockedBadges: [],
        lastActivityDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      await profileBox.put('current_user', defaultProfile);
    }

    // 5. Initialize default settings if none exist
    if (settingsBox.get('dark_mode_only') == null) {
      await settingsBox.put('dark_mode_only', true);
      await settingsBox.put('notifications_enabled', true);
      await settingsBox.put('alarm_sound', 'default');
      await settingsBox.put('vibrate_enabled', true);
      await settingsBox.put('snooze_duration_minutes', 10);
    }
  }

  // Helper getters
  static UserProfile getUserProfile() {
    return profileBox.get('current_user')!;
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    await profileBox.put('current_user', profile);
  }

  static List<Task> getAllTasks() {
    return tasksBox.values.toList();
  }

  static Future<void> saveTask(Task task) async {
    await tasksBox.put(task.id, task);
  }

  static Future<void> deleteTask(String id) async {
    await tasksBox.delete(id);
  }

  static Future<void> clearAllData() async {
    await tasksBox.clear();
    await profileBox.clear();
    await settingsBox.clear();
    await statsBox.clear();
    await init(); // re-initialize default values
  }
}
