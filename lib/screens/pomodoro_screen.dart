import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/gamification_provider.dart';
import '../providers/task_provider.dart';
import '../database/models/task_model.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({Key? key}) : super(key: key);

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  late ConfettiController _confettiController;
  Task? _assignedTask;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pomodoroProvider = Provider.of<PomodoroProvider>(context);
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);

    // Listen to background session state completed to award XP
    if (pomodoroProvider.completedSessions > 0 && 
        !pomodoroProvider.isRunning && 
        !pomodoroProvider.isPaused &&
        !pomodoroProvider.isBreak) {
      // Completed session triggers reward
      _confettiController.play();
      
      // Award 60 XP and 40 Coins for 25m Focus
      gamificationProvider.awardRewards(60, 40);
      gamificationProvider.addStudyTime(pomodoroProvider.focusDuration);

      if (_assignedTask != null) {
        // Increment assigned task progress or auto-complete it
        taskProvider.toggleTaskCompletion(
          _assignedTask!.id,
          onComplete: (xp, coins) {
            gamificationProvider.awardRewards(xp, coins);
          },
        );
        _assignedTask = null;
      }
    }

    final runningColor = pomodoroProvider.isBreak ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Focus Chamber', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Screen content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Assigned Study Quest Card
                _buildAssignedTaskCard(context, taskProvider.tasks),

                // Large Glowing Circular Ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow Background
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: runningColor.withOpacity(0.08),
                            blurRadius: 50,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                    ),
                    
                    // Progress Indicator Ring
                    SizedBox(
                      width: 230,
                      height: 230,
                      child: CircularProgressIndicator(
                        value: pomodoroProvider.progressPercentage,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFF16161A),
                        valueColor: AlwaysStoppedAnimation<Color>(runningColor),
                      ),
                    ),

                    // Countdown Label Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pomodoroProvider.timerString,
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pomodoroProvider.currentSessionType,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: runningColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                // Controls Row
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reset / Skip
                        if (pomodoroProvider.isRunning) ...[
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 28, color: Color(0xFF64748B)),
                            onPressed: () => pomodoroProvider.resetTimer(),
                          ),
                          const SizedBox(width: 24),
                        ],

                        // Play/Pause Action button
                        GestureDetector(
                          onTap: () {
                            if (!pomodoroProvider.isRunning) {
                              pomodoroProvider.startFocus();
                            } else if (pomodoroProvider.isPaused) {
                              pomodoroProvider.resume();
                            } else {
                              pomodoroProvider.pause();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: runningColor,
                              boxShadow: [
                                BoxShadow(
                                  color: runningColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Icon(
                              !pomodoroProvider.isRunning
                                  ? Icons.play_arrow_rounded
                                  : (pomodoroProvider.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // Skip Break
                        if (pomodoroProvider.isRunning) ...[
                          const SizedBox(width: 24),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, size: 28, color: Color(0xFF64748B)),
                            onPressed: () => pomodoroProvider.skip(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Configuration picker (25, 30, 45, 60 minutes)
                    if (!pomodoroProvider.isRunning)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [25, 30, 45, 60].map((mins) {
                            final isSel = pomodoroProvider.focusDuration == mins;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: ChoiceChip(
                                label: Text('$mins Mins'),
                                selected: isSel,
                                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSel ? Theme.of(context).colorScheme.primary : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    pomodoroProvider.setConfig(focus: mins);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ).animate().fade(delay: 150.ms),
                  ],
                ),
              ],
            ),
          ),

          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedTaskCard(BuildContext context, List<Task> allTasks) {
    final activeTasks = allTasks.where((t) => !t.completed).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSIGNED STUDY QUEST',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          _assignedTask == null
              ? DropdownButton<Task>(
                  isExpanded: true,
                  hint: const Text('Bind a study task to this focus session', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  dropdownColor: const Color(0xFF16161A),
                  underline: const SizedBox(),
                  items: activeTasks.map((task) {
                    return DropdownMenuItem(
                      value: task,
                      child: Text('${task.subject}: ${task.title}', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _assignedTask = val);
                  },
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_assignedTask!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(_assignedTask!.subject, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
                      onPressed: () => setState(() => _assignedTask = null),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
