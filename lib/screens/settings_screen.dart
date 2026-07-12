import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../database/hive_service.dart';
import '../providers/task_provider.dart';
import '../providers/gamification_provider.dart';
import '../database/models/task_model.dart';
import '../database/models/profile_model.dart';
import '../services/alarm_repository.dart';
import '../services/ai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alarmEnabled = true;
  double _alarmVolume = 0.8;
  bool _vibrateEnabled = true;
  String? _customSoundPath;
  int _snoozeMinutes = 5;
  String _geminiApiKey = '';
  final TextEditingController _apiKeyController = TextEditingController();
  final AudioPlayer _testAudioPlayer = AudioPlayer();
  bool _isPlayingTest = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _testAudioPlayer.dispose();
    super.dispose();
  }

  void _loadSettings() {
    setState(() {
      _alarmEnabled = AlarmRepository.isAlarmEnabled();
      _alarmVolume = AlarmRepository.getAlarmVolume();
      _vibrateEnabled = AlarmRepository.isVibrationEnabled();
      _customSoundPath = AlarmRepository.getCustomSoundPath();
      _snoozeMinutes = AlarmRepository.getSnoozeDuration();
      _geminiApiKey = AIService.getGeminiApiKey();
      _apiKeyController.text = _geminiApiKey;
    });
  }

  Future<void> _pickCustomSound() async {
    if (_isPlayingTest) {
      await _testAudioPlayer.stop();
      setState(() {
        _isPlayingTest = false;
      });
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          await AlarmRepository.setCustomSoundPath(path);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Custom alarm sound set: ${result.files.first.name}')),
          );
          _loadSettings();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick custom sound: $e')),
      );
    }
  }

  Future<void> _clearCustomSound() async {
    if (_isPlayingTest) {
      await _testAudioPlayer.stop();
      setState(() {
        _isPlayingTest = false;
      });
    }
    await AlarmRepository.setCustomSoundPath(null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm sound reset to default tone.')),
    );
    _loadSettings();
  }

  Future<void> _togglePlayTest() async {
    if (_isPlayingTest) {
      await _testAudioPlayer.stop();
      setState(() {
        _isPlayingTest = false;
      });
    } else {
      setState(() {
        _isPlayingTest = true;
      });
      try {
        if (_customSoundPath != null && _customSoundPath!.isNotEmpty) {
          await _testAudioPlayer.play(DeviceFileSource(_customSoundPath!));
        } else {
          await _testAudioPlayer.play(AssetSource('sounds/alarm_tone.wav'));
        }
      } catch (e) {
        setState(() {
          _isPlayingTest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play test sound: $e')),
        );
      }
    }
  }

  Future<void> _updateGeminiApiKey(String val) async {
    await AIService.saveGeminiApiKey(val);
    _loadSettings();
  }

  // Backup Data to JSON
  Future<void> _exportBackup() async {
    try {
      final tasks = HiveService.getAllTasks();
      final profile = HiveService.getUserProfile();

      final backupData = {
        'version': 1,
        'profile': {
          'name': profile.name,
          'xp': profile.xp,
          'coins': profile.coins,
          'level': profile.level,
          'currentStreak': profile.currentStreak,
          'longestStreak': profile.longestStreak,
          'unlockedBadges': profile.unlockedBadges,
          'totalCompletedTasks': profile.totalCompletedTasks,
          'totalFocusHours': profile.totalFocusHours,
        },
        'tasks': tasks.map((t) => {
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
        }).toList(),
      };

      final jsonString = jsonEncode(backupData);
      
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select where to save StudyQuest backup',
        fileName: 'studyquest_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsString(jsonString);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export backup: $e')),
      );
    }
  }

  // Restore Data from JSON
  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) return;

      final jsonString = utf8.decode(fileBytes);
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      if (backupData['version'] != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid backup version.')),
        );
        return;
      }

      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);

      final pData = backupData['profile'] as Map<String, dynamic>;
      final profile = UserProfile(
        name: pData['name'] as String,
        xp: pData['xp'] as int,
        coins: pData['coins'] as int,
        level: pData['level'] as int,
        currentStreak: pData['currentStreak'] as int,
        longestStreak: pData['longestStreak'] as int,
        unlockedBadges: (pData['unlockedBadges'] as List).cast<String>(),
        totalCompletedTasks: pData['totalCompletedTasks'] as int? ?? 0,
        totalFocusHours: pData['totalFocusHours'] as double? ?? 0.0,
      );
      await HiveService.saveUserProfile(profile);

      await HiveService.tasksBox.clear();
      final tList = backupData['tasks'] as List;
      for (var tData in tList) {
        final task = Task(
          id: tData['id'] as String,
          title: tData['title'] as String,
          description: tData['description'] as String,
          subject: tData['subject'] as String,
          date: DateTime.parse(tData['date'] as String),
          startTime: tData['startTime'] as String?,
          endTime: tData['endTime'] as String?,
          priority: tData['priority'] as int,
          repeat: tData['repeat'] as String,
          reminderMinutesBefore: tData['reminderMinutesBefore'] as int?,
          completed: tData['completed'] as bool,
          xpReward: tData['xpReward'] as int,
          coinReward: tData['coinReward'] as int,
          notes: tData['notes'] as String,
          colorHex: tData['colorHex'] as String,
          category: tData['category'] as String,
        );
        await HiveService.saveTask(task);
      }

      taskProvider.loadTasks();
      gamificationProvider.loadProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore backup: $e')),
      );
    }
  }

  void _clearDatabase() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16161A),
          title: const Text('Reset All Progress?', style: TextStyle(color: Color(0xFFEF4444))),
          content: const Text(
            'This action is irreversible. All completed tasks, levels, coins, study hours, and badges will be permanently erased.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);

                await HiveService.clearAllData();

                taskProvider.loadTasks();
                gamificationProvider.loadProfile();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database reset complete.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              child: const Text('Reset Data'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyQuest Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const BouncingScrollPhysics(),
        children: [
          // Section 1: Alarms & Notifications
          _buildSectionHeader('Study Quest Alarms'),
          Card(
            color: const Color(0xFF16161A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Study Alarms'),
                    subtitle: const Text('Rings loop tone at study time'),
                    value: _alarmEnabled,
                    onChanged: (val) async {
                      await AlarmRepository.setAlarmEnabled(val);
                      _loadSettings();
                    },
                  ),
                  const Divider(color: Color(0xFF26262E), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Alarm Ringing Volume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            const Icon(Icons.volume_mute, size: 18, color: Colors.grey),
                            Expanded(
                              child: Slider(
                                value: _alarmVolume,
                                min: 0.0,
                                max: 1.0,
                                activeColor: const Color(0xFF8B5CF6),
                                onChanged: (val) async {
                                  await AlarmRepository.setAlarmVolume(val);
                                  _loadSettings();
                                },
                              ),
                            ),
                            const Icon(Icons.volume_up, size: 18, color: Color(0xFF8B5CF6)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF26262E), height: 1),
                  SwitchListTile(
                    title: const Text('Repeating Vibration'),
                    subtitle: const Text('Vibrate 500ms ON / 500ms OFF pattern'),
                    value: _vibrateEnabled,
                    onChanged: (val) async {
                      await AlarmRepository.setVibrationEnabled(val);
                      _loadSettings();
                    },
                  ),
                  const Divider(color: Color(0xFF26262E), height: 1),
                  ListTile(
                    title: const Text('Snooze Duration'),
                    subtitle: const Text('Set duration for snoozing active alarm'),
                    trailing: DropdownButton<int>(
                      value: _snoozeMinutes,
                      dropdownColor: const Color(0xFF16161A),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 mins')),
                        DropdownMenuItem(value: 10, child: Text('10 mins')),
                        DropdownMenuItem(value: 15, child: Text('15 mins')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await AlarmRepository.setSnoozeDuration(val);
                          _loadSettings();
                        }
                      },
                    ),
                  ),
                  const Divider(color: Color(0xFF26262E), height: 1),
                  ListTile(
                    title: const Text('Alarm Sound Tone'),
                    subtitle: Text(
                      _customSoundPath == null
                          ? 'Default Alarm Sound'
                          : _customSoundPath!.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlayingTest ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            color: _isPlayingTest ? Colors.red : Colors.green,
                            size: 24,
                          ),
                          onPressed: _togglePlayTest,
                        ),
                        if (_customSoundPath != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                            onPressed: _clearCustomSound,
                          ),
                        IconButton(
                          icon: const Icon(Icons.audiotrack_rounded, color: Color(0xFF8B5CF6)),
                          onPressed: _pickCustomSound,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: AI Settings
          _buildSectionHeader('AI Services'),
          Card(
            color: const Color(0xFF16161A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gemini API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                    'Allows scanning and detecting timetables from uploaded images.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apiKeyController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter Gemini API Key',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                    onChanged: (val) {
                      _updateGeminiApiKey(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Backup & Restore
          _buildSectionHeader('Data Management'),
          Card(
            color: const Color(0xFF16161A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.blue),
                  title: const Text('Export JSON Backup'),
                  subtitle: const Text('Save your quests & profile statistics'),
                  onTap: _exportBackup,
                ),
                const Divider(color: Color(0xFF26262E), height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_rounded, color: Colors.green),
                  title: const Text('Import JSON Backup'),
                  subtitle: const Text('Restore quests from an existing backup'),
                  onTap: _importBackup,
                ),
                const Divider(color: Color(0xFF26262E), height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Clear / Reset Database', style: TextStyle(color: Color(0xFFEF4444))),
                  subtitle: const Text('Reset all streaks, levels and task logs'),
                  onTap: _clearDatabase,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: App info
          _buildSectionHeader('StudyQuest Info'),
          Card(
            color: const Color(0xFF16161A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('StudyQuest offline-first Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Version 1.0.0 (Offline Stable Release)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  SizedBox(height: 8),
                  Text(
                    'Built specifically for personal productivity. No data leaves your device. Designed with dark mode, high-priority overlays, and a gamified core loop.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.2),
      ),
    );
  }
}
