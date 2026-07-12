import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter_animate/flutter_animate.dart';
import '../hive_service.dart';
import '../task_provider.dart';
import '../gamification_provider.dart';
import '../task_model.dart';
import '../profile_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _vibrateEnabled = true;
  String _alarmSound = 'default';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    setState(() {
      _notificationsEnabled = HiveService.settingsBox.get('notifications_enabled', defaultValue: true);
      _vibrateEnabled = HiveService.settingsBox.get('vibrate_enabled', defaultValue: true);
      _alarmSound = HiveService.settingsBox.get('alarm_sound', defaultValue: 'default');
    });
  }

  // Backup Hive DB to JSON file
  Future<void> _backupData() async {
    try {
      final tasks = HiveService.getAllTasks();
      final profile = HiveService.getUserProfile();

      // Convert tasks to JSON-encodable maps
      final tasksMapList = tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'subject': t.subject,
        'date': t.date.toIso8601String(),
        'startTime': t.startTime,
        'endTime': t.endTime,
        'priority': t.priority,
        'repeat': t.repeat,
        'reminderMinutesBefore': t.reminderMinutesBefore,
        'completed': t.completed,
        'xpReward': t.xpReward,
        'coinReward': t.coinReward,
        'notes': t.notes,
        'colorHex': t.colorHex,
        'category': t.category,
      }).toList();

      final profileMap = {
        'name': profile.name,
        'xp': profile.xp,
        'coins': profile.coins,
        'level': profile.level,
        'currentStreak': profile.currentStreak,
        'longestStreak': profile.longestStreak,
        'lastActivityDate': profile.lastActivityDate?.toIso8601String(),
        'unlockedBadges': profile.unlockedBadges,
        'todayStudyTimeMinutes': profile.todayStudyTimeMinutes,
        'weeklyStudyTimeMinutes': profile.weeklyStudyTimeMinutes,
        'monthlyStudyTimeMinutes': profile.monthlyStudyTimeMinutes,
        'totalCompletedTasks': profile.totalCompletedTasks,
        'totalFocusHours': profile.totalFocusHours,
      };

      final backupData = {
        'version': 1,
        'tasks': tasksMapList,
        'profile': profileMap,
      };

      final jsonString = jsonEncode(backupData);

      // Save using file picker (export)
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select Backup Location',
        fileName: 'studyquest_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  // Restore Hive DB from JSON file
  Future<void> _restoreData() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final file = File(path);
          final jsonString = await file.readAsString();
          final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

          if (backupData['version'] != 1) {
            throw 'Unsupported backup version';
          }

          // 1. Restore Profile
          final pMap = backupData['profile'] as Map<String, dynamic>;
          final restoredProfile = UserProfile(
            name: pMap['name'] ?? 'Dev',
            xp: pMap['xp'] ?? 0,
            coins: pMap['coins'] ?? 0,
            level: pMap['level'] ?? 1,
            currentStreak: pMap['currentStreak'] ?? 0,
            longestStreak: pMap['longestStreak'] ?? 0,
            lastActivityDate: pMap['lastActivityDate'] != null ? DateTime.parse(pMap['lastActivityDate']) : null,
            unlockedBadges: List<String>.from(pMap['unlockedBadges'] ?? []),
            todayStudyTimeMinutes: pMap['todayStudyTimeMinutes'] ?? 0,
            weeklyStudyTimeMinutes: pMap['weeklyStudyTimeMinutes'] ?? 0,
            monthlyStudyTimeMinutes: pMap['monthlyStudyTimeMinutes'] ?? 0,
            totalCompletedTasks: pMap['totalCompletedTasks'] ?? 0,
            totalFocusHours: (pMap['totalFocusHours'] as num?)?.toDouble() ?? 0.0,
          );

          // 2. Restore Tasks
          final tList = backupData['tasks'] as List<dynamic>;
          final List<Task> restoredTasks = [];
          for (var item in tList) {
            final tMap = item as Map<String, dynamic>;
            restoredTasks.add(Task(
              id: tMap['id'],
              title: tMap['title'],
              description: tMap['description'] ?? '',
              subject: tMap['subject'] ?? 'General',
              date: DateTime.parse(tMap['date']),
              startTime: tMap['startTime'],
              endTime: tMap['endTime'],
              priority: tMap['priority'] ?? 1,
              repeat: tMap['repeat'] ?? 'none',
              reminderMinutesBefore: tMap['reminderMinutesBefore'],
              completed: tMap['completed'] ?? false,
              xpReward: tMap['xpReward'] ?? 20,
              coinReward: tMap['coinReward'] ?? 10,
              notes: tMap['notes'] ?? '',
              colorHex: tMap['colorHex'] ?? '#8B5CF6',
              category: tMap['category'] ?? 'Homework',
            ));
          }

          // 3. Save to Hive database boxes
          await HiveService.tasksBox.clear();
          for (var task in restoredTasks) {
            await HiveService.saveTask(task);
          }
          await HiveService.saveUserProfile(restoredProfile);

          // 4. Reload Provider States
          Provider.of<TaskProvider>(context, listen: false).loadTasks();
          Provider.of<GamificationProvider>(context, listen: false).loadProfile();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restoration failed: $e')),
      );
    }
  }

  // Export Tasks to CSV
  Future<void> _exportCsv() async {
    try {
      final tasks = HiveService.getAllTasks();

      final List<List<dynamic>> csvData = [
        ['ID', 'Title', 'Subject', 'Date', 'Start Time', 'End Time', 'Priority', 'Repeat', 'Completed', 'Category', 'Notes']
      ];

      for (var t in tasks) {
        csvData.add([
          t.id,
          t.title,
          t.subject,
          '${t.date.year}-${t.date.month}-${t.date.day}',
          t.startTime ?? '',
          t.endTime ?? '',
          t.priority == 2 ? 'High' : (t.priority == 1 ? 'Medium' : 'Low'),
          t.repeat,
          t.completed ? 'Yes' : 'No',
          t.category,
          t.notes,
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select CSV Export Path',
        fileName: 'studyquest_export.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(csvString);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV Export Complete!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV Export failed: $e')),
      );
    }
  }

  // Export Tasks to Excel
  Future<void> _exportExcel() async {
    try {
      final tasks = HiveService.getAllTasks();
      final excel = ex.Excel.createExcel();
      final sheet = excel['Quests'];
      
      // Header row
      sheet.appendRow([
        'ID', 'Title', 'Subject', 'Date', 'Start Time', 'End Time', 'Priority', 'Repeat', 'Completed', 'Category', 'Notes'
      ]);

      for (var t in tasks) {
        sheet.appendRow([
          t.id,
          t.title,
          t.subject,
          '${t.date.year}-${t.date.month}-${t.date.day}',
          t.startTime ?? '',
          t.endTime ?? '',
          t.priority == 2 ? 'High' : (t.priority == 1 ? 'Medium' : 'Low'),
          t.repeat,
          t.completed ? 'Yes' : 'No',
          t.category,
          t.notes,
        ]);
      }

      final bytes = excel.encode();
      if (bytes != null) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Select Excel Export Path',
          fileName: 'studyquest_export.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel Export Complete!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel Export failed: $e')),
      );
    }
  }

  Future<void> _resetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Application?'),
        content: const Text('This will delete all subjects, tasks, XP levels, streak progress, and settings permanently. This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.clearAllData();
      
      // Go back to onboarding
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Settings Room',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 20),

              // Alert configurations
              _buildSectionHeader('NOTIFICATION SETTINGS'),
              _buildToggleRow(
                context,
                title: 'Alarms Enabled',
                subtitle: 'Ring and vibrate for study session tasks',
                value: _notificationsEnabled,
                onChanged: (val) async {
                  await HiveService.settingsBox.put('notifications_enabled', val);
                  setState(() => _notificationsEnabled = val);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildToggleRow(
                context,
                title: 'Vibration Pattern',
                subtitle: 'Vibrate alongside alarm notifications',
                value: _vibrateEnabled,
                onChanged: (val) async {
                  await HiveService.settingsBox.put('vibrate_enabled', val);
                  setState(() => _vibrateEnabled = val);
                },
              ),
              const SizedBox(height: 24),

              // Data Import Export backups
              _buildSectionHeader('BACKUP & SYNC (OFFLINE)'),
              _buildSettingsActionCard(
                context,
                title: 'Create JSON Backup',
                subtitle: 'Export tasks and profile level records to a JSON file',
                icon: Icons.cloud_download_rounded,
                onTap: _backupData,
              ),
              const SizedBox(height: 12),
              _buildSettingsActionCard(
                context,
                title: 'Restore JSON Data',
                subtitle: 'Import database state back from a JSON backup file',
                icon: Icons.cloud_upload_rounded,
                onTap: _restoreData,
              ),
              const SizedBox(height: 24),

              // Formats exports
              _buildSectionHeader('EXPORT QUESTS'),
              _buildSettingsActionCard(
                context,
                title: 'Export to CSV Spreadsheet',
                subtitle: 'Save quest tasks history into comma-separated formats',
                icon: Icons.table_chart_rounded,
                onTap: _exportCsv,
              ),
              const SizedBox(height: 12),
              _buildSettingsActionCard(
                context,
                title: 'Export to Excel File (.xlsx)',
                subtitle: 'Download formatted study planner schedules offline',
                icon: Icons.bar_chart_outlined,
                onTap: _exportExcel,
              ),
              const SizedBox(height: 32),

              // Destructive operations
              _buildSectionHeader('DANGER ZONE'),
              _buildSettingsActionCard(
                context,
                title: 'Full Database Reset',
                subtitle: 'Wipe all profile progression, streak gold, and task records',
                icon: Icons.delete_forever_rounded,
                color: Colors.redAccent,
                onTap: _resetData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.5),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF16161A),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: themeColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
        onTap: onTap,
      ),
    );
  }
}
