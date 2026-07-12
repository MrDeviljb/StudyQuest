import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../database/models/task_model.dart';
import '../providers/gamification_provider.dart';
import '../services/alarm_service.dart';

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

  List<Task> _getTasksForDay(DateTime day, List<Task> allTasks) {
    return allTasks.where((task) {
      return isSameDay(task.date, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final selectedDayTasks = _getTasksForDay(_selectedDay ?? _focusedDay, taskProvider.tasks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Planner / Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Table Calendar Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.02)),
            ),
            child: TableCalendar<Task>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
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
              eventLoader: (day) => _getTasksForDay(day, taskProvider.tasks),
              
              // Custom Stylings
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Emerald dots for tasks
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                outsideDaysVisible: false,
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              headerStyle: HeaderStyle(
                formatButtonDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                titleCentered: true,
                titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: primaryColor),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: primaryColor),
              ),
            ),
          ).animate().fade().scale(duration: 300.ms),

          const SizedBox(height: 12),

          // Day's Tasks Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay == null
                      ? 'Select a day to view quests'
                      : 'Quests for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '${selectedDayTasks.length} Scheduled',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Day's Tasks List
          Expanded(
            child: selectedDayTasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🛡️', style: TextStyle(fontSize: 32)),
          SizedBox(height: 12),
          Text(
            'Clear day! No quests scheduled.',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ).animate().fade(),
    );
  }

  Widget _buildTaskRow(
      BuildContext context, Task task, TaskProvider taskProvider, GamificationProvider gamificationProvider) {
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
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: color),
              const SizedBox(width: 12),
              
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
                          if (task.startTime != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              task.startTime!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),

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
}
