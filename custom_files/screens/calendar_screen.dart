import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../task_provider.dart';
import '../task_model.dart';
import '../gamification_provider.dart';
import '../alarm_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Get tasks for a specific day to draw calendar event dots
  List<Task> _getTasksForDay(DateTime day, List<Task> allTasks) {
    return allTasks.where((task) {
      return isSameDay(task.date, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final allTasks = taskProvider.tasks;
    
    final selectedDayTasks = _getTasksForDay(_selectedDay ?? _focusedDay, allTasks);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Quest Map',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
              ),
              const SizedBox(height: 16),

              // Calendar Widget
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.03)),
                ),
                child: TableCalendar<Task>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  eventLoader: (day) => _getTasksForDay(day, allTasks),
                  
                  // Styling calendar
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    weekendStyle: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    formatButtonDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    formatButtonTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    iconColor: const Color(0xFF64748B),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(color: Color(0xFFE2E8F0)),
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Colors.amber, // default dots
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  calendarBuilders: CalendarBuilders(
                    // Custom markers to render multiple colored dots
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.take(3).map((task) {
                          final color = Color(int.parse(task.colorHex.replaceAll('#', '0xFF')));
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.0),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Selected day quests list header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Quests for ${_selectedDay?.day}/${_selectedDay?.month}/${_selectedDay?.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),

              // Tasks list below
              Expanded(
                child: selectedDayTasks.isEmpty
                    ? _buildNoTasksState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: selectedDayTasks.length,
                        itemBuilder: (context, index) {
                          final task = selectedDayTasks[index];
                          return _buildTaskRow(context, task, taskProvider, gamificationProvider);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoTasksState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏖️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          const Text(
            'Rest Day!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF64748B)),
          ),
          Text(
            'No tasks scheduled for this day.',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildTaskRow(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
    GamificationProvider gamificationProvider,
  ) {
    final color = Color(int.parse(task.colorHex.replaceAll('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showEditTaskDialog(context, task, taskProvider),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Colored left bar
                Container(width: 6, color: color),
                const SizedBox(width: 12),

                // Checkbox
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

                // Text details
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

                // Rewards
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${task.xpReward} XP',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                      Text(
                        '+${task.coinReward} Gold',
                        style: const TextStyle(fontSize: 9, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  // Same task details sheet modal logic from tasks screen
  void _showEditTaskDialog(BuildContext context, Task task, TaskProvider taskProvider) {
    // Navigate or call bottom sheet (defined previously, so we redirect the user to double tap edit or open a short picker)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Swipe to tasks log to edit detailed notes.'), duration: Duration(seconds: 1)),
    );
  }
}
