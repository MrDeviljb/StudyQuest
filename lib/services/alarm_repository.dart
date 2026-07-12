import 'dart:convert';
import '../database/hive_service.dart';

class AlarmHistoryEntry {
  final String taskId;
  final String taskTitle;
  final String subject;
  final String status; // 'Completed', 'Missed', 'Dismissed', 'Snoozed'
  final DateTime timestamp;

  AlarmHistoryEntry({
    required this.taskId,
    required this.taskTitle,
    required this.subject,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'taskTitle': taskTitle,
      'subject': subject,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AlarmHistoryEntry.fromMap(Map<String, dynamic> map) {
    return AlarmHistoryEntry(
      taskId: map['taskId'] ?? '',
      taskTitle: map['taskTitle'] ?? '',
      subject: map['subject'] ?? '',
      status: map['status'] ?? 'Dismissed',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class AlarmRepository {
  static const String _historyKey = 'alarm_history';
  static const String _alarmEnabledKey = 'alarm_enabled';
  static const String _alarmVolumeKey = 'alarm_volume';
  static const String _vibrationEnabledKey = 'alarm_vibration_enabled';
  static const String _customSoundPathKey = 'alarm_custom_sound_path';
  static const String _snoozeDurationKey = 'alarm_snooze_duration';

  // Settings getters & setters
  static bool isAlarmEnabled() {
    return HiveService.settingsBox.get(_alarmEnabledKey, defaultValue: true) as bool;
  }

  static Future<void> setAlarmEnabled(bool enabled) async {
    await HiveService.settingsBox.put(_alarmEnabledKey, enabled);
  }

  static double getAlarmVolume() {
    return HiveService.settingsBox.get(_alarmVolumeKey, defaultValue: 0.8) as double;
  }

  static Future<void> setAlarmVolume(double volume) async {
    await HiveService.settingsBox.put(_alarmVolumeKey, volume);
  }

  static bool isVibrationEnabled() {
    return HiveService.settingsBox.get(_vibrationEnabledKey, defaultValue: true) as bool;
  }

  static Future<void> setVibrationEnabled(bool enabled) async {
    await HiveService.settingsBox.put(_vibrationEnabledKey, enabled);
  }

  static String? getCustomSoundPath() {
    return HiveService.settingsBox.get(_customSoundPathKey) as String?;
  }

  static Future<void> setCustomSoundPath(String? path) async {
    await HiveService.settingsBox.put(_customSoundPathKey, path);
  }

  static int getSnoozeDuration() {
    return HiveService.settingsBox.get(_snoozeDurationKey, defaultValue: 5) as int;
  }

  static Future<void> setSnoozeDuration(int minutes) async {
    await HiveService.settingsBox.put(_snoozeDurationKey, minutes);
  }

  // History loggers
  static List<AlarmHistoryEntry> getHistory() {
    final rawList = HiveService.settingsBox.get(_historyKey, defaultValue: []) as List;
    return rawList.map((item) {
      if (item is String) {
        return AlarmHistoryEntry.fromMap(jsonDecode(item));
      }
      return AlarmHistoryEntry.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Future<void> addHistoryEntry(AlarmHistoryEntry entry) async {
    final history = getHistory();
    history.insert(0, entry); // newest first
    // Limit to 100 entries to save space
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }
    final rawList = history.map((e) => jsonEncode(e.toMap())).toList();
    await HiveService.settingsBox.put(_historyKey, rawList);
  }

  static Future<void> clearHistory() async {
    await HiveService.settingsBox.put(_historyKey, []);
  }
}
