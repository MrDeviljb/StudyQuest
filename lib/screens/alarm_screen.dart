import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../providers/task_provider.dart';
import '../providers/gamification_provider.dart';
import '../database/models/task_model.dart';
import 'package:intl/intl.dart';

class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> alarmPayload;

  const AlarmScreen({Key? key, required this.alarmPayload}) : super(key: key);

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late String _taskId;
  late String _taskTitle;
  late String _taskSubject;
  
  String _currentTimeString = '';
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _taskId = widget.alarmPayload['id'] as String;
    _taskTitle = widget.alarmPayload['title'] as String? ?? 'Study Session';
    _taskSubject = widget.alarmPayload['subject'] as String? ?? 'General Study';

    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });

    // Start audio & vibration ring when the alarm screen opens
    _startAlarmRing();
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      _currentTimeString = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  Future<void> _startAlarmRing() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    // Find task in local DB or make dummy task
    final task = taskProvider.tasks.firstWhere(
      (t) => t.id == _taskId,
      orElse: () => Task(
        id: _taskId,
        title: _taskTitle,
        description: '',
        subject: _taskSubject,
        date: DateTime.now(),
        priority: 1,
        repeat: 'none',
        xpReward: 50,
        coinReward: 20,
        notes: '',
        colorHex: '#3B82F6',
        category: 'Study Session',
      ),
    );

    await AlarmService.startAlarm(task);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeTimer?.cancel();
    AlarmService.stopAlarm(); // stop ringing/vibrating if disposed
    super.dispose();
  }

  // Dismiss Alarm Action
  void _onDismiss() async {
    await AlarmService.dismissActiveAlarm();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // Start Study Action
  void _onStartStudy() async {
    await AlarmService.stopAlarm();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/pomodoro',
      (route) => false,
      arguments: _taskId,
    );
  }

  // Snooze Action (Minutes option)
  void _onSnooze(int minutes) async {
    await AlarmService.snoozeActiveAlarm(minutes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarm snoozed for $minutes minutes!')),
    );
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // Complete Task Action
  void _onComplete() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);

    // Stop alarm first and complete active alarm
    await AlarmService.completeActiveAlarm((xp, coins) {
      taskProvider.toggleTaskCompletion(
        _taskId,
        onComplete: (awardedXp, awardedCoins) {
          gamificationProvider.awardRewards(awardedXp, awardedCoins);
        },
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fantastic! Reward coins & XP added.')),
    );
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F12), Color(0xFF060608)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Radial pulsing background glow
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 280 * (1.0 + (_pulseController.value * 0.12)),
                      height: 280 * (1.0 + (_pulseController.value * 0.12)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            themeColor.withOpacity(0.15),
                            themeColor.withOpacity(0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Alarm status header & Clock
                    Column(
                      children: [
                        const Text(
                          '⏰ STUDY ALARM RINGING',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ).animate().fade().scale(delay: 200.ms),
                        const SizedBox(height: 16),
                        // Current time digital clock
                        Text(
                          _currentTimeString,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier', // clean digital style
                          ),
                        ).animate().fade(),
                        const SizedBox(height: 12),
                        Text(
                          _taskSubject,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    // Study Quest Center Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161A).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: themeColor.withOpacity(0.3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.08),
                            blurRadius: 24,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_stories_rounded,
                            size: 54,
                            color: Colors.purpleAccent,
                          ).animate().shake(delay: 600.ms, duration: 600.ms),
                          const SizedBox(height: 20),
                          Text(
                            _taskTitle,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Quest time has arrived! Will you begin focus or log completion?',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.3),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 500.ms).scale(curve: Curves.easeOutBack),

                    // Controls panel
                    Column(
                      children: [
                        // Button 1: Start Study
                        ElevatedButton.icon(
                          onPressed: _onStartStudy,
                          icon: const Icon(Icons.play_circle_outline_rounded, size: 28),
                          label: const Text(
                            'Start Study Session',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                        ).animate().slideY(begin: 0.3, duration: 400.ms),
                        const SizedBox(height: 12),

                        // Button 2: Complete task
                        ElevatedButton.icon(
                          onPressed: _onComplete,
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 24),
                          label: const Text(
                            'Complete Task',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ).animate().slideY(begin: 0.4, duration: 420.ms),
                        const SizedBox(height: 12),

                        // Row 3: Snooze Buttons (5 min & 10 min)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _onSnooze(5),
                                icon: const Icon(Icons.snooze_rounded, size: 18),
                                label: const Text('Snooze 5m', style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amberAccent,
                                  side: BorderSide(color: Colors.amberAccent.withOpacity(0.4)),
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _onSnooze(10),
                                icon: const Icon(Icons.snooze_rounded, size: 18),
                                label: const Text('Snooze 10m', style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber,
                                  side: BorderSide(color: Colors.amber.withOpacity(0.4)),
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().slideY(begin: 0.5, duration: 450.ms),
                        const SizedBox(height: 12),

                        // Button 4: Dismiss / Skip
                        TextButton(
                          onPressed: _onDismiss,
                          child: const Text(
                            'Dismiss Alarm',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ).animate().fade(delay: 500.ms),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
