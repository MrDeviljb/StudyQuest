import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../alarm_service.dart';
import '../task_provider.dart';
import '../gamification_provider.dart';
import '../task_model.dart';

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

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _taskId = widget.alarmPayload['id'] as String;
    _taskTitle = widget.alarmPayload['title'] as String? ?? 'Study Task';
    _taskSubject = widget.alarmPayload['subject'] as String? ?? 'General Study';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _dismissAlarm() {
    AlarmService.cancelAlarm(_taskId);
  }

  void _onStartStudy() {
    _dismissAlarm();
    // Navigate to Pomodoro tab with task payload
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/pomodoro',
      (route) => false,
      arguments: _taskId,
    );
  }

  void _onSnooze() {
    _dismissAlarm();
    
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final task = taskProvider.tasks.firstWhere((t) => t.id == _taskId);
    
    // Reschedule in 10 minutes
    final now = DateTime.now().add(const Duration(minutes: 10));
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    final snoozedTask = task.copyWith(
      startTime: timeString,
      date: now,
    );
    
    AlarmService.scheduleAlarm(snoozedTask);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm snoozed for 10 minutes!')),
    );
    
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _onComplete() {
    _dismissAlarm();

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);

    taskProvider.toggleTaskCompletion(
      _taskId,
      onComplete: (xp, coins) {
        gamificationProvider.awardRewards(xp, coins);
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Awesome job! Task completed.')),
    );

    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _onSkip() {
    _dismissAlarm();
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

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
              // Radial Pulsing Glow in background
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 300 * (1.0 + (_pulseController.value * 0.15)),
                      height: 300 * (1.0 + (_pulseController.value * 0.15)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        radialGradient: RadialGradient(
                          colors: [
                            color.withOpacity(0.18),
                            color.withOpacity(0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header Status
                    Column(
                      children: [
                        const Text(
                          '⏰ STUDY TIME!',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ).animate().fade().scale(delay: 200.ms),
                        const SizedBox(height: 12),
                        Text(
                          _taskSubject,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                          textAlign: TextAlign.center,
                        ).animate().fade().slideY(begin: -0.2),
                      ],
                    ),

                    // Task Info Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161A).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.08),
                            blurRadius: 30,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '📖',
                            style: TextStyle(fontSize: 48),
                          ).animate().shake(delay: 600.ms),
                          const SizedBox(height: 20),
                          Text(
                            _taskTitle,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Will you conquer this quest today?',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 500.ms).scale(curve: Curves.easeOutBack),

                    // Action Controls
                    Column(
                      children: [
                        // Large "Start Study" button
                        ElevatedButton.icon(
                          onPressed: _onStartStudy,
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: const Text(
                            'Start Study Session',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 64),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ).animate().slideY(begin: 0.5, duration: 400.ms),
                        const SizedBox(height: 16),

                        // Secondary actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _onSnooze,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF334155)),
                                  minimumSize: const Size(0, 54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Snooze 10m',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _onComplete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981), // Emerald
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Complete',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ).animate().slideY(begin: 0.6, duration: 450.ms),
                        const SizedBox(height: 16),

                        // Skip button
                        TextButton(
                          onPressed: _onSkip,
                          child: const Text(
                            'Skip / Dismiss Alarm',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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
