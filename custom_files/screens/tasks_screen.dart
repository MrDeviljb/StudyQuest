import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../task_provider.dart';
import '../gamification_provider.dart';
import '../task_model.dart';
import '../alarm_service.dart';
import 'dart:ui';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'Incomplete'; // 'Incomplete', 'Completed', 'All'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    
    // Apply filters based on local tab
    List<Task> displayTasks = taskProvider.filteredTasks;
    if (_activeTab == 'Incomplete') {
      displayTasks = displayTasks.where((t) => !t.completed).toList();
    } else if (_activeTab == 'Completed') {
      displayTasks = displayTasks.where((t) => t.completed).toList();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Quest Log',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  taskProvider.setSearchQuery(val);
                },
                decoration: InputDecoration(
                  hintText: 'Search quests...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            taskProvider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF16161A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Horizontal scroll filters (Subject / Priority / Sort)
              _buildFilterChips(context, taskProvider),
              const SizedBox(height: 16),

              // Completed/Incomplete toggle tabs
              _buildSegmentedControl(context),
              const SizedBox(height: 16),

              // Tasks List
              Expanded(
                child: displayTasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: displayTasks.length,
                        itemBuilder: (context, index) {
                          final task = displayTasks[index];
                          return _buildDismissibleTaskRow(context, task, taskProvider, gamificationProvider);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, taskProvider),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, TaskProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Sort Dropdown Chip
          _buildDropdownChip(
            context,
            label: 'Sort: ${provider.sortBy}',
            icon: Icons.sort_rounded,
            items: ['Date', 'Priority', 'Title'],
            onChanged: (val) {
              if (val != null) provider.setSortBy(val);
            },
          ),
          const SizedBox(width: 8),

          // Subject Dropdown Chip
          _buildDropdownChip(
            context,
            label: provider.selectedSubject == 'All' ? 'Subjects' : provider.selectedSubject,
            icon: Icons.book_rounded,
            items: provider.allSubjects,
            onChanged: (val) {
              if (val != null) provider.setSelectedSubject(val);
            },
          ),
          const SizedBox(width: 8),

          // Priority Dropdown Chip
          _buildDropdownChip(
            context,
            label: provider.selectedPriority ?? 'Priority',
            icon: Icons.priority_high_rounded,
            items: ['All', 'Low', 'Medium', 'High'],
            onChanged: (val) {
              if (val == 'All') {
                provider.setSelectedPriority(null);
              } else {
                provider.setSelectedPriority(val);
              }
            },
          ),
          const SizedBox(width: 8),

          // Clear button if active filters
          if (provider.selectedSubject != 'All' ||
              provider.selectedPriority != null ||
              provider.searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                provider.clearFilters();
                _searchController.clear();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset'),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: null, // Always display prompt label
            hint: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
            dropdownColor: const Color(0xFF16161A),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
            items: items.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return Row(
      children: [
        _buildSegmentButton('Incomplete'),
        const SizedBox(width: 8),
        _buildSegmentButton('Completed'),
        const SizedBox(width: 8),
        _buildSegmentButton('All'),
      ],
    );
  }

  Widget _buildSegmentButton(String tabName) {
    final isActive = _activeTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : const BorderSide(color: Colors.transparent).value,
          ),
        ),
        child: Text(
          tabName,
          style: TextStyle(
            color: isActive ? Theme.of(context).colorScheme.primary : const Color(0xFF64748B),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Quest board is clear!',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new study task or import your timetable to level up.',
            style: TextStyle(color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildDismissibleTaskRow(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
    GamificationProvider gamificationProvider,
  ) {
    final color = Color(int.parse(task.colorHex.replaceAll('#', '0xFF')));

    return Dismissible(
      key: Key(task.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.check_circle_rounded, color: Colors.green),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
      ),
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete task
          await AlarmService.cancelAlarm(task.id);
          await taskProvider.deleteTask(task.id);
          
          // Show Undo SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Quest discarded from board.'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  taskProvider.undoDelete();
                },
              ),
            ),
          );
        } else {
          // Complete task (swipe right)
          taskProvider.toggleTaskCompletion(
            task.id,
            onComplete: (xp, coins) {
              gamificationProvider.awardRewards(xp, coins);
            },
          );
          taskProvider.loadTasks(); // refresh
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.02)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEditTaskDialog(context, task, taskProvider),
          child: Row(
            children: [
              // Colored bar indicator
              Container(
                width: 6,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Completed checkbox
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

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 4),
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

              // Gamification rewards display
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
    );
  }

  // DIALOGS & SHEET MODALS
  void _showAddTaskDialog(BuildContext context, TaskProvider taskProvider) {
    // We reuse a comprehensive bottom sheet layout for fully detailed task creation
    _showTaskSheet(context, taskProvider: taskProvider);
  }

  void _showEditTaskDialog(BuildContext context, Task task, TaskProvider taskProvider) {
    _showTaskSheet(context, task: task, taskProvider: taskProvider);
  }

  void _showTaskSheet(BuildContext context, {Task? task, required TaskProvider taskProvider}) {
    final isEdit = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final subjectController = TextEditingController(text: task?.subject ?? '');
    final notesController = TextEditingController(text: task?.notes ?? '');

    String category = task?.category ?? 'Homework';
    int priority = task?.priority ?? 1; // Medium
    String repeat = task?.repeat ?? 'none';
    int? reminder = task?.reminderMinutesBefore ?? 10;
    
    DateTime date = task?.date ?? DateTime.now();
    TimeOfDay? startTime = task?.startTime != null ? _parseTimeOfDay(task!.startTime!) : null;
    TimeOfDay? endTime = task?.endTime != null ? _parseTimeOfDay(task!.endTime!) : null;

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
              padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Modify Quest Task' : 'New Quest Task',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextField(
                      controller: titleController,
                      decoration: _getInputDecoration('Task Title', Icons.title_rounded),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      decoration: _getInputDecoration('Description', Icons.description_rounded),
                    ),
                    const SizedBox(height: 12),

                    // Subject
                    TextField(
                      controller: subjectController,
                      decoration: _getInputDecoration('Subject Name', Icons.book_rounded),
                    ),
                    const SizedBox(height: 12),

                    // Date Picker Trigger
                    ListTile(
                      leading: const Icon(Icons.date_range_rounded, color: Color(0xFF8B5CF6)),
                      title: const Text('Task Date'),
                      subtitle: Text('${date.year}-${date.month}-${date.day}'),
                      tileColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setModalState(() => date = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Time Picker Triggers (Start & End)
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Start Time', style: TextStyle(fontSize: 13)),
                            subtitle: Text(startTime?.format(context) ?? 'Set time'),
                            tileColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setModalState(() => startTime = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListTile(
                            title: const Text('End Time', style: TextStyle(fontSize: 13)),
                            subtitle: Text(endTime?.format(context) ?? 'Set time'),
                            tileColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setModalState(() => endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Priority / Repeat / Reminder config rows
                    _buildSettingsRow(
                      context,
                      setModalState,
                      priority: priority,
                      repeat: repeat,
                      reminder: reminder,
                      category: category,
                      onPriorityChanged: (val) => priority = val,
                      onRepeatChanged: (val) => repeat = val,
                      onReminderChanged: (val) => reminder = val,
                      onCategoryChanged: (val) => category = val,
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: _getInputDecoration('Notes & References', Icons.edit_note_rounded),
                    ),
                    const SizedBox(height: 20),

                    // Add / Save Button
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await AlarmService.cancelAlarm(task!.id);
                                await taskProvider.deleteTask(task.id);
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                minimumSize: const Size(0, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final title = titleController.text.trim();
                              final subject = subjectController.text.trim();
                              if (title.isEmpty) return;

                              // Save priority color keys
                              String colorHex = '#8B5CF6';
                              if (priority == 2) colorHex = '#EF4444'; // high
                              if (priority == 0) colorHex = '#3B82F6'; // low

                              final updated = Task(
                                id: isEdit ? task!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                                title: title,
                                description: descController.text.trim(),
                                subject: subject.isEmpty ? 'General' : subject,
                                date: date,
                                startTime: startTime?.format(context),
                                endTime: endTime?.format(context),
                                priority: priority,
                                repeat: repeat,
                                reminderMinutesBefore: reminder,
                                completed: isEdit ? task!.completed : false,
                                xpReward: (priority + 1) * 20,
                                coinReward: (priority + 1) * 10,
                                notes: notesController.text.trim(),
                                colorHex: colorHex,
                                category: category,
                              );

                              if (isEdit) {
                                await taskProvider.updateTask(updated);
                              } else {
                                await taskProvider.addTask(updated);
                              }

                              // Reschedule alarm
                              if (updated.reminderMinutesBefore != null) {
                                await AlarmService.scheduleAlarm(updated);
                              } else {
                                await AlarmService.cancelAlarm(updated.id);
                              }

                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(isEdit ? 'Save Changes' : 'Confirm Quest', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context,
    StateSetter setModalState, {
    required int priority,
    required String repeat,
    required int? reminder,
    required String category,
    required Function(int) onPriorityChanged,
    required Function(String) onRepeatChanged,
    required Function(int?) onReminderChanged,
    required Function(String) onCategoryChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Category
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Category', style: TextStyle(fontSize: 13)),
              DropdownButton<String>(
                value: category,
                dropdownColor: const Color(0xFF16161A),
                underline: const SizedBox(),
                items: ['Homework', 'Exam', 'Study Session', 'Project', 'Quiz']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => onCategoryChanged(val));
                  }
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          // Priority
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Priority', style: TextStyle(fontSize: 13)),
              DropdownButton<int>(
                value: priority,
                dropdownColor: const Color(0xFF16161A),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Low', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 1, child: Text('Medium', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 2, child: Text('High', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => onPriorityChanged(val));
                  }
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          // Repeat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Repeat', style: TextStyle(fontSize: 13)),
              DropdownButton<String>(
                value: repeat,
                dropdownColor: const Color(0xFF16161A),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'daily', child: Text('Daily', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => onRepeatChanged(val));
                  }
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          // Reminder offset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reminder Alert', style: TextStyle(fontSize: 13)),
              DropdownButton<int?>(
                value: reminder,
                dropdownColor: const Color(0xFF16161A),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('No Alert', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 5, child: Text('5 mins before', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 10, child: Text('10 mins before', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 30, child: Text('30 mins before', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 60, child: Text('1 hour before', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (val) {
                  setModalState(() => onReminderChanged(val));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Parse time of day from e.g. "09:00 AM" or "19:00"
  TimeOfDay _parseTimeOfDay(String value) {
    if (value.contains('AM') || value.contains('PM')) {
      final parts = value.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } else {
      final parts = value.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }
}
