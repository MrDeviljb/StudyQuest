import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../pomodoro_provider.dart';
import '../gamification_provider.dart';
import '../task_provider.dart';
import '../task_model.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({Key? key}) : super(key: key);

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  String? _associatedTaskId;
  Task? _associatedTask;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Intercept taskId routed from alarm or task click
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      _associatedTaskId = args;
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      try {
        _associatedTask = taskProvider.tasks.firstWhere((t) => t.id == _associatedTaskId);
      } catch (_) {
        _associatedTask = null;
      }
    }
  }

  void _onTimerEnd(int durationMinutes) {
    // Add focus duration to statistics
    final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);
    gamificationProvider.addStudyTime(durationMinutes);
    
    // If there was an associated task, we also grant some coins/XP
    if (_associatedTask != null) {
      gamificationProvider.awardRewards(20, 10);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Focus completed for ${_associatedTask!.title}! Earned +20 XP, +10 Coins!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Focus session complete! +25 XP awarded.'),
          backgroundColor: Colors.green,
        ),
      );
      gamificationProvider.awardRewards(25, 5); // default focus rewards
    }
  }

  @override
  Widget build(BuildContext context) {
    final pomodoroProvider = Provider.of<PomodoroProvider>(context);
    final theme = Theme.of(context);
    final isBreak = pomodoroProvider.isBreak;
    
    // Choose theme colors based on focus/break state
    final primaryColor = isBreak ? const Color(0xFF10B981) : const Color(0xFFEF4444); // green vs red
    final stateTitle = pomodoroProvider.currentSessionType;

    // Listen to changes in running status, and trigger rewards when timer completes
    // In Flutter, doing side-effects in build is unsafe. We check when duration hit 0
    // The provider internally resets and transitions, so we hook into status changes.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Room'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Associated Task Header
              Column(
                children: [
                  Text(
                    stateTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fade(),
                  const SizedBox(height: 8),
                  if (_associatedTask != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Focusing on: ${_associatedTask!.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fade().slideY(begin: -0.1)
                  else
                    const Text(
                      'Universal Focus Session',
                      style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),

              // Timer Display (Ring + Text)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ring Glow
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.08),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                    ),
                    
                    // Circular Progress
                    SizedBox(
                      width: 230,
                      height: 230,
                      child: CircularProgressIndicator(
                        value: pomodoroProvider.progressPercentage,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFF1E1E24),
                        color: primaryColor,
                      ),
                    ),

                    // Countdown text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pomodoroProvider.timerString,
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isBreak ? 'Rest Period' : 'Stay Focused',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

              // Statistics summary
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆 completed today: ', style: TextStyle(color: Color(0xFF64748B))),
                  Text(
                    '${pomodoroProvider.completedSessions} sessions',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),

              // Control Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  children: [
                    // Major Start/Pause action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!pomodoroProvider.isRunning) ...[
                          // Start Focus Button
                          ElevatedButton.icon(
                            onPressed: () {
                              pomodoroProvider.startFocus();
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 28),
                            label: const Text('Start Focus', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(180, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ] else ...[
                          // Pause / Resume Toggle
                          if (!pomodoroProvider.isPaused)
                            ElevatedButton.icon(
                              onPressed: () {
                                pomodoroProvider.pause();
                              },
                              icon: const Icon(Icons.pause_rounded, size: 28),
                              label: const Text('Pause', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(140, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () {
                                pomodoroProvider.resume();
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 28),
                              label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(140, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          const SizedBox(width: 12),
                          // Skip Button
                          OutlinedButton(
                            onPressed: () {
                              pomodoroProvider.skip();
                              if (!pomodoroProvider.isBreak) {
                                // if skipped focus, give callback
                                _onTimerEnd(25 - (pomodoroProvider.remainingSeconds ~/ 60));
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF334155)),
                              minimumSize: const Size(80, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Skip', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Reset Button
                    if (pomodoroProvider.isRunning)
                      TextButton(
                        onPressed: () {
                          pomodoroProvider.resetTimer();
                        },
                        child: const Text('Reset Session', style: TextStyle(color: Color(0xFF64748B))),
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
