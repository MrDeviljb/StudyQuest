import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../providers/task_provider.dart';
import '../providers/gamification_provider.dart';
import '../database/models/task_model.dart';
import 'pomodoro_screen.dart';
import 'timetable_import_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 22) return 'Good Evening';
    return 'Good Night';
  }

  // A list of fallback offline quotes
  static const List<String> _quotes = [
    "Focus on being productive instead of busy. — Tim Ferriss",
    "The secret of getting ahead is getting started. — Mark Twain",
    "It always seems impossible until it's done. — Nelson Mandela",
    "Don't wish it were easier. Wish you were better. — Jim Rohn",
    "Today a reader, tomorrow a leader. — Margaret Fuller",
    "There are no shortcuts to any place worth going. — Beverly Sills",
    "You do not rise to the level of your goals. You fall to the level of your systems. — James Clear",
  ];

  String _getDailyQuote() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final profile = gamificationProvider.profile;

    // Filter today's tasks
    final today = DateTime.now();
    final todayTasks = taskProvider.tasks.where((task) {
      return task.date.year == today.year &&
          task.date.month == today.month &&
          task.date.day == today.day;
    }).toList();

    final completedToday = todayTasks.where((t) => t.completed).length;
    final totalToday = todayTasks.length;
    final todayProgress = totalToday > 0 ? completedToday / totalToday : 0.0;

    // Find next upcoming alarm/task
    Task? nextAlarmTask;
    final now = DateTime.now();
    final incompleteAlarms = taskProvider.tasks.where((t) => !t.completed && t.reminderMinutesBefore != null).toList();
    if (incompleteAlarms.isNotEmpty) {
      // Sort tasks by date & start time to find the closest upcoming one
      incompleteAlarms.sort((a, b) => a.date.compareTo(b.date));
      nextAlarmTask = incompleteAlarms.firstWhere(
        (t) => t.date.isAfter(now) || (t.date.year == now.year && t.date.month == now.month && t.date.day == now.day),
        orElse: () => incompleteAlarms.first,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background subtle blur shapes
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), // padding bottom for navigation bar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gamification Stats Header
                  _buildStatsHeader(context, profile),
                  const SizedBox(height: 24),

                  // Dynamic Greeting Card
                  _buildGreetingCard(context, profile.name),
                  const SizedBox(height: 24),

                  // Today's Progress Section
                  _buildProgressSection(context, todayProgress, completedToday, totalToday),
                  const SizedBox(height: 24),

                  // Quick Action Grid (Pomodoro / Import Timetable)
                  _buildQuickActions(context),
                  const SizedBox(height: 24),

                  // Upcoming Alarm Alert Widget
                  if (nextAlarmTask != null) ...[
                    _buildUpcomingAlarm(context, nextAlarmTask),
                    const SizedBox(height: 24),
                  ],

                  // Today's Tasks Summary
                  _buildTodayTasksHeader(context),
                  const SizedBox(height: 12),
                  if (todayTasks.isEmpty)
                    _buildEmptyTasksCard(context)
                  else
                    ...todayTasks.take(3).map((task) => _buildTodayTaskRow(context, task, taskProvider, gamificationProvider)),
                  
                  if (todayTasks.length > 3)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // Jump to tasks tab
                          Navigator.pushReplacementNamed(context, '/home', arguments: 1);
                        },
                        child: const Text('View All Today\'s Tasks'),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Daily Quote
                  _buildQuoteCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddTask(context, taskProvider),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  // STATS HEADER
  Widget _buildStatsHeader(BuildContext context, dynamic profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Level Indicator
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('⭐ ', style: TextStyle(fontSize: 14)),
                  Text(
                    'LV ${profile.level}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // XP bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: profile.xp / (profile.level * 100),
                      backgroundColor: const Color(0xFF2D2D35),
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.xp}/${profile.level * 100} XP',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),

        // Coins & Streaks
        Row(
          children: [
            // Coins
            Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '${profile.coins}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Streak
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '${profile.currentStreak}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orangeAccent),
                ),
              ],
            ),
          ],
        ),
      ],
    ).animate().fade(duration: 400.ms);
  }

  // GREETING CARD
  Widget _buildGreetingCard(BuildContext context, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
        Text(
          name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
        ),
      ],
    ).animate().fade(delay: 100.ms).slideX(begin: -0.1);
  }

  // PROGRESS RING SECTION
  Widget _buildProgressSection(BuildContext context, double progress, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Circular Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFF26262E),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Progress text details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Study Progress',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0
                      ? 'Conquered $completed of $total tasks. Level up awaits!'
                      : 'No tasks scheduled for today yet. Make a quest!',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms).scale(curve: Curves.easeOutBack);
  }

  // QUICK ACTIONS GRID
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        // Pomodoro
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PomodoroScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.timer_rounded, size: 28, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Focus Pomodoro',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Timetable Import
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TimetableImportScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.upload_file_rounded, size: 28, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Import Timetable',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fade(delay: 250.ms);
  }

  // UPCOMING ALARM CARD
  Widget _buildUpcomingAlarm(BuildContext context, Task task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B15),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_on_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Alarm Alert',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.subject}: ${task.title} at ${task.startTime ?? '08:00 AM'}',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 300.ms).slideY(begin: 0.1);
  }

  // TASKS HEADER
  Widget _buildTodayTasksHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Today\'s Quests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFF64748B)),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home', arguments: 1);
          },
        ),
      ],
    ).animate().fade(delay: 350.ms);
  }

  Widget _buildEmptyTasksCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: const Column(
        children: [
          Text('🛡️', style: TextStyle(fontSize: 32)),
          SizedBox(height: 12),
          Text(
            'All clean! No tasks due today.',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ).animate().fade(delay: 400.ms);
  }

  // INDIVIDUAL TASK ROW
  Widget _buildTodayTaskRow(
      BuildContext context, Task task, TaskProvider taskProvider, GamificationProvider gamificationProvider) {
    final color = Color(int.parse(task.colorHex.replaceAll('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left indicator strip
              Container(width: 6, color: color),
              const SizedBox(width: 12),
              
              // Completion checkbox
              Checkbox(
                value: task.completed,
                activeColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                onChanged: (val) {
                  taskProvider.toggleTaskCompletion(
                    task.id,
                    onComplete: (xp, coins) {
                      gamificationProvider.awardRewards(xp, coins);
                    },
                  );
                },
              ),
              const SizedBox(width: 8),

              // Title and Subject
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: task.completed ? const Color(0xFF64748B) : Colors.white,
                          decoration: task.completed ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.subject,
                              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (task.startTime != null)
                            Text(
                              task.startTime!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Gamification XP Reward badge
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${task.xpReward} XP',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  // MOTIVATIONAL QUOTE CARD
  Widget _buildQuoteCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        children: [
          const Text(
            '💡 INSPIRATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getDailyQuote(),
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Color(0xFFE2E8F0),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fade(delay: 500.ms);
  }

  // QUICK ADD DIALOG BOTTOM SHEET
  void _showQuickAddTask(BuildContext context, TaskProvider taskProvider) {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    String selectedCategory = 'Homework';
    int selectedPriority = 1; // Medium
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Add Task',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title Input
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subject Input
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject Name',
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category & Priority selectors in a Row
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            dropdownColor: const Color(0xFF1E293B),
                            underline: const SizedBox(),
                            isExpanded: true,
                            items: ['Homework', 'Exam', 'Study Session', 'Project', 'Quiz']
                                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedCategory = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Priority selection
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<int>(
                            value: selectedPriority,
                            dropdownColor: const Color(0xFF1E293B),
                            underline: const SizedBox(),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Low Priority')),
                              DropdownMenuItem(value: 1, child: Text('Medium Priority')),
                              DropdownMenuItem(value: 2, child: Text('High Priority')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedPriority = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Add button
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      final subject = subjectController.text.trim();
                      if (title.isEmpty) return;

                      // Determine default colors
                      String colorHex = '#8B5CF6';
                      if (selectedPriority == 2) colorHex = '#EF4444'; // high = red
                      if (selectedPriority == 0) colorHex = '#3B82F6'; // low = blue

                      final newTask = Task(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        description: '',
                        subject: subject.isEmpty ? 'General' : subject,
                        date: selectedDate,
                        priority: selectedPriority,
                        repeat: 'none',
                        completed: false,
                        xpReward: (selectedPriority + 1) * 20,
                        coinReward: (selectedPriority + 1) * 10,
                        notes: '',
                        colorHex: colorHex,
                        category: selectedCategory,
                      );

                      taskProvider.addTask(newTask);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Add Quest Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
