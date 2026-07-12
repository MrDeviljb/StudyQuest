import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../providers/gamification_provider.dart';
import '../database/models/task_model.dart';
import '../services/alarm_service.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest log / Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context, taskProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showTaskFormDialog(context, taskProvider, null),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          if (taskProvider.searchQuery.isNotEmpty ||
              taskProvider.selectedCategory != 'All' ||
              taskProvider.selectedSubject != 'All' ||
              taskProvider.selectedPriority != null ||
              taskProvider.selectedFilterDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear Filters', style: TextStyle(fontSize: 12)),
                    onPressed: () => taskProvider.clearFilters(),
                  ),
                  const SizedBox(width: 8),
                  if (taskProvider.selectedCategory != 'All')
                    Chip(label: Text('Cat: ${taskProvider.selectedCategory}', style: const TextStyle(fontSize: 12))),
                  if (taskProvider.selectedSubject != 'All')
                    Chip(label: Text('Subj: ${taskProvider.selectedSubject}', style: const TextStyle(fontSize: 12))),
                  if (taskProvider.selectedPriority != null)
                    Chip(label: Text('Priority: ${taskProvider.selectedPriority}', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => taskProvider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search quests by title, subject or notes...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF16161A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Tasks Listing List
          Expanded(
            child: taskProvider.filteredTasks.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // extra bottom padding for floating bar
                    physics: const BouncingScrollPhysics(),
                    itemCount: taskProvider.filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = taskProvider.filteredTasks[index];
                      return _buildTaskCard(context, task, taskProvider, gamificationProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🛡️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text(
          'No quests match your parameters.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Modify filters or create a new quest using the button above.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    ).animate().fade();
  }

  // INDIVIDUAL LIST CARD
  Widget _buildTaskCard(
      BuildContext context, Task task, TaskProvider taskProvider, GamificationProvider gamificationProvider) {
    final color = Color(int.parse(task.colorHex.replaceAll('#', '0xFF')));

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) async {
        await taskProvider.deleteTask(task.id);
        await AlarmService.cancelAlarm(task.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted task: ${task.title}'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                taskProvider.undoDelete();
                if (taskProvider.lastDeletedTask != null) {
                  AlarmService.scheduleAlarm(taskProvider.lastDeletedTask!);
                }
              },
            ),
          ),
        );
      },
      child: Container(
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
                // Priority color stripe indicator
                Container(width: 6, color: color),
                const SizedBox(width: 12),
                
                // Complete checkbox
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

                // Main Info
                Expanded(
                  child: InkWell(
                    onTap: () => _showTaskFormDialog(context, taskProvider, task),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: task.completed ? const Color(0xFF64748B) : Colors.white,
                              decoration: task.completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              if (task.startTime != null) ...[
                                const Icon(Icons.schedule, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 2),
                                Text(
                                  task.startTime!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                              if (task.repeat != 'none') ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 2),
                                Text(
                                  task.repeat,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Gamification rewards info
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${task.xpReward} XP',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                        Text(
                          '+${task.coinReward} G',
                          style: const TextStyle(fontSize: 10, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  // FILTER SHEET BOTTOM MODAL
  void _showFilterSheet(BuildContext context, TaskProvider taskProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter & Sort Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Sort Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sort By', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: taskProvider.sortBy,
                        dropdownColor: const Color(0xFF16161A),
                        underline: const SizedBox(),
                        items: ['Date', 'Priority', 'Title']
                            .map((sort) => DropdownMenuItem(value: sort, child: Text(sort)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            taskProvider.setSortBy(val);
                            setModalState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF26262E)),

                  // Category Filter Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Category', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: taskProvider.selectedCategory,
                        dropdownColor: const Color(0xFF16161A),
                        underline: const SizedBox(),
                        items: taskProvider.allCategories
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            taskProvider.setSelectedCategory(val);
                            setModalState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF26262E)),

                  // Subject Filter Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subject', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: taskProvider.selectedSubject,
                        dropdownColor: const Color(0xFF16161A),
                        underline: const SizedBox(),
                        items: taskProvider.allSubjects
                            .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            taskProvider.setSelectedSubject(val);
                            setModalState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF26262E)),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Parameters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ADD/EDIT QUEST DETAILED DIALOG
  void _showTaskFormDialog(BuildContext context, TaskProvider taskProvider, Task? existingTask) {
    final isEdit = existingTask != null;
    final titleController = TextEditingController(text: existingTask?.title ?? '');
    final descController = TextEditingController(text: existingTask?.description ?? '');
    final subjectController = TextEditingController(text: existingTask?.subject ?? '');
    final notesController = TextEditingController(text: existingTask?.notes ?? '');

    String selectedCategory = existingTask?.category ?? 'Homework';
    int selectedPriority = existingTask?.priority ?? 1;
    String selectedRepeat = existingTask?.repeat ?? 'none';
    int? reminderMinutes = existingTask?.reminderMinutesBefore;
    DateTime selectedDate = existingTask?.date ?? DateTime.now();
    TimeOfDay? selectedTime;

    if (existingTask?.startTime != null) {
      final parts = existingTask!.startTime!.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1].split(' ')[0]);
      if (existingTask.startTime!.contains('PM') && h != 12) h += 12;
      selectedTime = TimeOfDay(hour: h, minute: m);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16161A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(isEdit ? 'Edit Quest' : 'Add New Quest', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Quest Title *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(labelText: 'Subject *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description (Short)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Quest Study Notes'),
                      ),
                      const SizedBox(height: 16),

                      // Date selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quest Date:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          TextButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      
                      // Time selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Alarm Time:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          TextButton.icon(
                            icon: const Icon(Icons.alarm, size: 14),
                            label: Text(selectedTime != null ? selectedTime!.format(context) : 'None'),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ],
                      ),

                      // Repeat mode Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recurrence:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          DropdownButton<String>(
                            value: selectedRepeat,
                            dropdownColor: const Color(0xFF16161A),
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'none', child: Text('No Repeat')),
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedRepeat = val);
                              }
                            },
                          ),
                        ],
                      ),

                      // Reminder Offset Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reminder Alert:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          DropdownButton<int?>(
                            value: reminderMinutes,
                            dropdownColor: const Color(0xFF16161A),
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('No Reminder')),
                              DropdownMenuItem(value: 0, child: Text('On Time')),
                              DropdownMenuItem(value: 5, child: Text('5m Before')),
                              DropdownMenuItem(value: 10, child: Text('10m Before')),
                              DropdownMenuItem(value: 15, child: Text('15m Before')),
                            ],
                            onChanged: (val) {
                              setDialogState(() => reminderMinutes = val);
                            },
                          ),
                        ],
                      ),

                      // Category Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Category:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          DropdownButton<String>(
                            value: selectedCategory,
                            dropdownColor: const Color(0xFF16161A),
                            underline: const SizedBox(),
                            items: ['Homework', 'Exam', 'Study Session', 'Project', 'Quiz']
                                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedCategory = val);
                              }
                            },
                          ),
                        ],
                      ),

                      // Priority Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Priority:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          DropdownButton<int>(
                            value: selectedPriority,
                            dropdownColor: const Color(0xFF16161A),
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Low')),
                              DropdownMenuItem(value: 1, child: Text('Medium')),
                              DropdownMenuItem(value: 2, child: Text('High')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedPriority = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final subject = subjectController.text.trim();
                    if (title.isEmpty || subject.isEmpty) return;

                    String colorHex = '#8B5CF6'; // purple default
                    if (selectedPriority == 2) colorHex = '#EF4444'; // high = red
                    if (selectedPriority == 0) colorHex = '#3B82F6'; // low = blue

                    String? startTimeString;
                    if (selectedTime != null) {
                      startTimeString = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                    }

                    final task = Task(
                      id: isEdit ? existingTask!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      description: descController.text.trim(),
                      subject: subject,
                      date: selectedDate,
                      startTime: startTimeString,
                      priority: selectedPriority,
                      repeat: selectedRepeat,
                      reminderMinutesBefore: reminderMinutes,
                      completed: isEdit ? existingTask!.completed : false,
                      xpReward: (selectedPriority + 1) * 20,
                      coinReward: (selectedPriority + 1) * 10,
                      notes: notesController.text.trim(),
                      colorHex: colorHex,
                      category: selectedCategory,
                    );

                    if (isEdit) {
                      await taskProvider.updateTask(task);
                      await AlarmService.cancelAlarm(task.id);
                    } else {
                      await taskProvider.addTask(task);
                    }

                    // Reschedule alarm
                    await AlarmService.scheduleAlarm(task);

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEdit ? 'Save Changes' : 'Create Quest'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
