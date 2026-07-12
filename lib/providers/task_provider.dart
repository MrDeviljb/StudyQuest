import 'package:flutter/material.dart';
import '../database/models/task_model.dart';
import '../database/hive_service.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  Task? _lastDeletedTask;
  
  // Filter & Search states
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSubject = 'All';
  String? _selectedPriority; // 'Low', 'Medium', 'High', null
  String _sortBy = 'Date'; // 'Date', 'Priority', 'Title'
  DateTime? _selectedFilterDate;

  List<Task> get tasks => _tasks;
  Task? get lastDeletedTask => _lastDeletedTask;
  
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedSubject => _selectedSubject;
  String? get selectedPriority => _selectedPriority;
  String get sortBy => _sortBy;
  DateTime? get selectedFilterDate => _selectedFilterDate;

  TaskProvider() {
    loadTasks();
  }

  void loadTasks() {
    _tasks = HiveService.getAllTasks();
    notifyListeners();
  }

  // Get list of tasks applying search, filter, and sort
  List<Task> get filteredTasks {
    List<Task> result = List.from(_tasks);

    // 1. Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((task) {
        return task.title.toLowerCase().contains(query) ||
            task.description.toLowerCase().contains(query) ||
            task.subject.toLowerCase().contains(query) ||
            task.notes.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Category Filter
    if (_selectedCategory != 'All') {
      result = result.where((task) => task.category == _selectedCategory).toList();
    }

    // 3. Subject Filter
    if (_selectedSubject != 'All') {
      result = result.where((task) => task.subject == _selectedSubject).toList();
    }

    // 4. Priority Filter
    if (_selectedPriority != null) {
      int pVal = _selectedPriority == 'High' ? 2 : (_selectedPriority == 'Medium' ? 1 : 0);
      result = result.where((task) => task.priority == pVal).toList();
    }

    // 5. Date Filter
    if (_selectedFilterDate != null) {
      result = result.where((task) {
        return task.date.year == _selectedFilterDate!.year &&
            task.date.month == _selectedFilterDate!.month &&
            task.date.day == _selectedFilterDate!.day;
      }).toList();
    }

    // 6. Sorting
    if (_sortBy == 'Date') {
      result.sort((a, b) {
        int dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        // if same date, sort by start time
        if (a.startTime != null && b.startTime != null) {
          return a.startTime!.compareTo(b.startTime!);
        }
        return 0;
      });
    } else if (_sortBy == 'Priority') {
      // Descending priority: High (2) -> Medium (1) -> Low (0)
      result.sort((a, b) => b.priority.compareTo(a.priority));
    } else if (_sortBy == 'Title') {
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return result;
  }

  // Get distinct subjects for filter dropdown
  List<String> get allSubjects {
    final subjects = _tasks.map((t) => t.subject).where((s) => s.isNotEmpty).toSet().toList();
    subjects.sort();
    return ['All', ...subjects];
  }

  // Get distinct categories for filter dropdown
  List<String> get allCategories {
    final categories = _tasks.map((t) => t.category).where((c) => c.isNotEmpty).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  // Setters for search and filters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSelectedSubject(String subject) {
    _selectedSubject = subject;
    notifyListeners();
  }

  void setSelectedPriority(String? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setFilterDate(DateTime? date) {
    _selectedFilterDate = date;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _selectedSubject = 'All';
    _selectedPriority = null;
    _selectedFilterDate = null;
    _sortBy = 'Date';
    notifyListeners();
  }

  // CRUD Operations
  Future<void> addTask(Task task) async {
    _tasks.add(task);
    await HiveService.saveTask(task);
    notifyListeners();
  }

  Future<void> updateTask(Task updatedTask) async {
    final idx = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (idx != -1) {
      _tasks[idx] = updatedTask;
      await HiveService.saveTask(updatedTask);
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _lastDeletedTask = _tasks[idx];
      _tasks.removeAt(idx);
      await HiveService.deleteTask(id);
      notifyListeners();
    }
  }

  Future<void> undoDelete() async {
    if (_lastDeletedTask != null) {
      _tasks.add(_lastDeletedTask!);
      await HiveService.saveTask(_lastDeletedTask!);
      _lastDeletedTask = null;
      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(String id, {required Function(int xp, int coins) onComplete}) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final task = _tasks[idx];
      final newStatus = !task.completed;
      final updatedTask = task.copyWith(completed: newStatus);
      
      _tasks[idx] = updatedTask;
      await HiveService.saveTask(updatedTask);

      if (newStatus) {
        // Trigger gamification rewards
        onComplete(task.xpReward, task.coinReward);
      } else {
        // Deduct rewards if uncompleted
        onComplete(-task.xpReward, -task.coinReward);
      }
      notifyListeners();
    }
  }
}
