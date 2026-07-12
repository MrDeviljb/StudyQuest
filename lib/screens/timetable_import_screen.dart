import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../database/models/task_model.dart';
import '../services/timetable_parser.dart';
import '../services/alarm_service.dart';
import '../services/ai_service.dart';

class TimetableImportScreen extends StatefulWidget {
  const TimetableImportScreen({Key? key}) : super(key: key);

  @override
  State<TimetableImportScreen> createState() => _TimetableImportScreenState();
}

class _TimetableImportScreenState extends State<TimetableImportScreen> {
  bool _isLoading = false;
  String? _selectedFileName;
  TimetableParseResult? _parseResult;
  final TextEditingController _apiKeyController = TextEditingController();

  // Active configurations
  String _selectedSheetName = '';
  TimetableLayoutType _selectedLayoutType = TimetableLayoutType.list;
  int _selectedHeaderIdx = 0;
  int _selectedDayIdx = 0;
  int _selectedTimeIdx = 0;
  int _selectedSubjectIdx = 0;

  // Dynamic preview list that the user can edit
  List<ImportedTask> _previewTasks = [];

  // Toggle for the manual correction Import Wizard
  bool _showWizard = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = AIService.getGeminiApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParseFile() async {
    setState(() {
      _isLoading = true;
      _parseResult = null;
      _selectedFileName = null;
      _previewTasks = [];
      _showWizard = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'jpg', 'png', 'jpeg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file data.')),
          );
        });
        return;
      }

      final filename = file.name.toLowerCase();
      final isImage = filename.endsWith('.png') || filename.endsWith('.jpg') || filename.endsWith('.jpeg');

      if (isImage) {
        if (!AIService.hasApiKey()) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your Gemini API Key first to parse timetable images!')),
          );
          return;
        }

        String mimeType = 'image/jpeg';
        if (filename.endsWith('.png')) mimeType = 'image/png';

        final tasks = await AIService.parseTimetableImage(fileBytes, mimeType);

        setState(() {
          _isLoading = false;
          _selectedFileName = file.name;
          _parseResult = TimetableParseResult(
            isSuccess: true,
            confidenceScore: 1.0,
            layoutType: TimetableLayoutType.list,
            allSheets: {'Image': []},
            selectedSheet: 'Image',
            parsedTasks: tasks,
          );
          _selectedSheetName = 'Image';
          _previewTasks = tasks;
          _showWizard = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully auto-detected ${tasks.length} tasks from timetable image!')),
        );
      } else {
        // Excel/CSV Flow
        TimetableParseResult pr;
        if (filename.endsWith('.csv')) {
          pr = TimetableParser.parseCsv(fileBytes);
        } else {
          pr = TimetableParser.parseExcel(fileBytes);
        }

        setState(() {
          _isLoading = false;
          _selectedFileName = file.name;
          _parseResult = pr;

          if (pr.isSuccess) {
            _selectedSheetName = pr.selectedSheet;
            _selectedLayoutType = pr.layoutType;
            _selectedHeaderIdx = (pr.dayIdx != null && pr.layoutType != TimetableLayoutType.list) ? pr.dayIdx! : 0;
            _selectedDayIdx = pr.dayIdx ?? 0;
            _selectedTimeIdx = pr.timeIdx ?? 0;
            _selectedSubjectIdx = pr.subjectIdx ?? 0;
            _previewTasks = List.from(pr.parsedTasks);
            _showWizard = pr.confidenceScore < 0.90;
          }
        });

        if (pr.isSuccess && pr.confidenceScore < 0.90) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Automatic detection confidence is low. Opening Import Wizard for adjustment!'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parsing failed: $e')),
        );
      });
    }
  }

  // Handle switching sheets in Excel workbooks
  void _changeSheet(String sheetName) {
    if (_parseResult == null) return;
    setState(() {
      _selectedSheetName = sheetName;
      final tempPr = TimetableParser.parseSheet(_parseResult!.allSheets, sheetName);
      
      _selectedLayoutType = tempPr.layoutType;
      _selectedHeaderIdx = (tempPr.dayIdx != null && tempPr.layoutType != TimetableLayoutType.list) ? tempPr.dayIdx! : 0;
      _selectedDayIdx = tempPr.dayIdx ?? 0;
      _selectedTimeIdx = tempPr.timeIdx ?? 0;
      _selectedSubjectIdx = tempPr.subjectIdx ?? 0;
      _previewTasks = List.from(tempPr.parsedTasks);
      _showWizard = tempPr.confidenceScore < 0.90;
    });
  }

  // Regenerate preview list on wizard updates
  void _regenerateTasks() {
    if (_parseResult == null) return;
    final rows = _parseResult!.allSheets[_selectedSheetName] ?? [];
    if (rows.isEmpty) return;

    int maxCols = rows.first.length;
    int maxRows = rows.length;

    int headerIdx = _selectedHeaderIdx < maxRows ? _selectedHeaderIdx : 0;
    int dayIdx = _selectedDayIdx;
    int timeIdx = _selectedTimeIdx;
    int subjectIdx = _selectedSubjectIdx;

    if (_selectedLayoutType == TimetableLayoutType.gridDaysHeader) {
      if (dayIdx >= maxRows) dayIdx = 0;
      if (timeIdx >= maxCols) timeIdx = 0;
    } else if (_selectedLayoutType == TimetableLayoutType.gridTimesHeader) {
      if (dayIdx >= maxCols) dayIdx = 0;
      if (timeIdx >= maxRows) timeIdx = 0;
    } else {
      if (dayIdx >= maxCols) dayIdx = 0;
      if (timeIdx >= maxCols) timeIdx = 0;
      if (subjectIdx >= maxCols) subjectIdx = 0;
    }

    final tasks = TimetableParser.parseTasks(
      rows,
      _selectedLayoutType,
      headerIdx,
      dayIdx,
      timeIdx,
      _selectedLayoutType == TimetableLayoutType.list ? subjectIdx : null,
    );

    setState(() {
      _previewTasks = tasks;
    });
  }

  // Confirm Import & Save Tasks
  void _importTasks() {
    final selectedTasks = _previewTasks.where((t) => t.isSelected && t.subject.trim().isNotEmpty).toList();
    if (selectedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No selected tasks to import!')),
      );
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    int successCount = 0;

    for (var parsedTask in selectedTasks) {
      int weekday = _mapWeekday(parsedTask.day);
      DateTime targetDate = _getNextWeekdayDate(weekday);

      final task = Task(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}_${successCount + 1}',
        title: '${parsedTask.subject} Lecture',
        description: parsedTask.endTime != null
            ? 'Duration: ${parsedTask.startTime} to ${parsedTask.endTime}'
            : 'Class start: ${parsedTask.startTime}',
        subject: parsedTask.subject,
        date: targetDate,
        startTime: parsedTask.startTime,
        endTime: parsedTask.endTime,
        priority: 1, // Medium priority
        repeat: 'weekly', // Repeating weekly
        reminderMinutesBefore: 10, // Reminder 10 mins before
        completed: false,
        xpReward: 50, // 50 XP
        coinReward: 20, // 20 Coins
        notes: 'Auto-imported from timetable ${parsedTask.day}',
        colorHex: '#3B82F6',
        category: 'Study Session',
      );

      taskProvider.addTask(task);
      AlarmService.scheduleAlarm(task);
      successCount++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported $successCount recurring weekly tasks!')),
    );

    Navigator.pop(context);
  }

  int _mapWeekday(String value) {
    final v = value.toLowerCase();
    if (v.contains('mon')) return 1;
    if (v.contains('tue')) return 2;
    if (v.contains('wed')) return 3;
    if (v.contains('thu')) return 4;
    if (v.contains('fri')) return 5;
    if (v.contains('sat')) return 6;
    if (v.contains('sun')) return 7;
    return 1;
  }

  DateTime _getNextWeekdayDate(int targetWeekday) {
    final now = DateTime.now();
    int currentWeekday = now.weekday;
    int difference = targetWeekday - currentWeekday;
    if (difference <= 0) {
      difference += 7;
    }
    return now.add(Duration(days: difference));
  }

  String _getRowSample(List<String> row) {
    final nonEm = row.where((c) => c.isNotEmpty).take(3).join(', ');
    if (nonEm.isEmpty) return '(empty row)';
    if (nonEm.length > 22) return '${nonEm.substring(0, 19)}...';
    return nonEm;
  }

  String _getColSample(List<List<String>> rows, int colIdx) {
    final List<String> samples = [];
    for (int r = 0; r < rows.length && samples.length < 3; r++) {
      if (colIdx < rows[r].length && rows[r][colIdx].isNotEmpty) {
        samples.add(rows[r][colIdx]);
      }
    }
    final text = samples.join(', ');
    if (text.isEmpty) return '(empty column)';
    if (text.length > 22) return '${text.substring(0, 19)}...';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Offline Importer', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 ', style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: Text(
                      'Upload your timetable file. We support Excel sheets, CSVs, and timetable photos/images. The AI layout engine automatically extracts times and tasks.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Gemini API Key Field (for Image Processing)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology_rounded, color: Colors.purpleAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI Image Timetable Detector',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To auto-detect schedules from photos (PNG/JPG), enter your Gemini API Key below.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apiKeyController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter Gemini API Key',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                      ),
                    ),
                    onChanged: (val) {
                      AIService.saveGeminiApiKey(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Select File Button
            if (_selectedFileName == null)
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickAndParseFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        _isLoading
                            ? CircularProgressIndicator(color: primaryColor)
                            : Icon(Icons.cloud_upload_rounded, size: 48, color: primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          _isLoading ? 'Analyzing sheet schemas...' : 'Tap to Select Timetable (CSV / XLSX / Image)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _isLoading ? Colors.white : primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // File selected header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, color: Colors.green, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedFileName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('${_previewTasks.length} tasks found in sheet', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.amber),
                      onPressed: _pickAndParseFile,
                    )
                  ],
                ),
              ).animate().fade(),

            if (_parseResult != null) ...[
              const SizedBox(height: 20),

              // Sheet Selector (Only if parsed via excel multiple sheets)
              if (_selectedSheetName != 'Image' && _parseResult!.allSheets.length > 1) _buildSheetSelector(),

              // Wizard Toggle (Only if parsed via excel/csv)
              if (_selectedSheetName != 'Image') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Timetable Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    TextButton.icon(
                      onPressed: () => setState(() => _showWizard = !_showWizard),
                      icon: Icon(_showWizard ? Icons.expand_less : Icons.tune_rounded, size: 16),
                      label: Text(_showWizard ? 'Hide Import Wizard' : 'Open Import Wizard', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Import Wizard Container
                if (_showWizard) _buildWizardPanel().animate().fade().slideY(begin: -0.1, end: 0),
              ],

              const SizedBox(height: 28),
              const Text('Import Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),

              // Preview List
              if (_previewTasks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Center(
                    child: Text(
                      'No valid tasks parsed yet. Use the Import Wizard above to check layout mappings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _previewTasks.length,
                  itemBuilder: (context, index) {
                    return _buildPreviewCard(_previewTasks[index], index);
                  },
                ),

              const SizedBox(height: 36),

              // Import Action Button
              ElevatedButton(
                onPressed: _importTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Confirm Import & Setup Alarms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Sheet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _parseResult!.allSheets.keys.map((sheetName) {
              final isSelected = sheetName == _selectedSheetName;
              return GestureDetector(
                onTap: () => _changeSheet(sheetName),
                child: Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.05),
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ] : null,
                  ),
                  child: Text(
                    sheetName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWizardPanel() {
    final rows = _parseResult?.allSheets[_selectedSheetName] ?? [];
    if (rows.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text('Import Wizard Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildWizardDropdown<TimetableLayoutType>(
            label: 'Timetable Layout Type',
            value: _selectedLayoutType,
            items: const [
              DropdownMenuItem(value: TimetableLayoutType.list, child: Text('List Format (Columns)')),
              DropdownMenuItem(value: TimetableLayoutType.gridDaysHeader, child: Text('Grid Format (Days on Top)')),
              DropdownMenuItem(value: TimetableLayoutType.gridTimesHeader, child: Text('Grid Format (Times on Top)')),
            ],
            onChanged: (val) {
              setState(() {
                _selectedLayoutType = val!;
                _regenerateTasks();
              });
            },
          ),
          const SizedBox(height: 12),

          _buildWizardDropdown<int>(
            label: 'Header Row Index',
            value: _selectedHeaderIdx,
            items: List.generate(
              rows.length,
              (idx) => DropdownMenuItem(
                value: idx,
                child: Text('Row ${idx + 1}: ${_getRowSample(rows[idx])}'),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedHeaderIdx = val!;
                _regenerateTasks();
              });
            },
          ),
          const SizedBox(height: 12),

          _buildWizardDropdown<int>(
            label: _selectedLayoutType == TimetableLayoutType.gridTimesHeader
                ? 'Day Column Index'
                : 'Day Column/Row Index',
            value: _selectedDayIdx,
            items: List.generate(
              _selectedLayoutType == TimetableLayoutType.gridDaysHeader
                  ? rows.length
                  : (rows.isNotEmpty ? rows.first.length : 0),
              (idx) => DropdownMenuItem(
                value: idx,
                child: Text(_selectedLayoutType == TimetableLayoutType.gridDaysHeader
                    ? 'Row ${idx + 1}: ${_getRowSample(rows[idx])}'
                    : 'Col ${idx + 1}: ${_getColSample(rows, idx)}'),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedDayIdx = val!;
                _regenerateTasks();
              });
            },
          ),
          const SizedBox(height: 12),

          _buildWizardDropdown<int>(
            label: _selectedLayoutType == TimetableLayoutType.gridTimesHeader
                ? 'Time Row Index'
                : 'Time Column Index',
            value: _selectedTimeIdx,
            items: List.generate(
              _selectedLayoutType == TimetableLayoutType.gridTimesHeader
                  ? rows.length
                  : (rows.isNotEmpty ? rows.first.length : 0),
              (idx) => DropdownMenuItem(
                value: idx,
                child: Text(_selectedLayoutType == TimetableLayoutType.gridTimesHeader
                    ? 'Row ${idx + 1}: ${_getRowSample(rows[idx])}'
                    : 'Col ${idx + 1}: ${_getColSample(rows, idx)}'),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedTimeIdx = val!;
                _regenerateTasks();
              });
            },
          ),
          
          if (_selectedLayoutType == TimetableLayoutType.list) ...[
            const SizedBox(height: 12),
            _buildWizardDropdown<int>(
              label: 'Subject / Task Column Index',
              value: _selectedSubjectIdx,
              items: List.generate(
                rows.isNotEmpty ? rows.first.length : 0,
                (idx) => DropdownMenuItem(
                  value: idx,
                  child: Text('Col ${idx + 1}: ${_getColSample(rows, idx)}'),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedSubjectIdx = val!;
                  _regenerateTasks();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWizardDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final hasVal = items.any((item) => item.value == value);
    final activeVal = hasVal ? value : (items.isNotEmpty ? items.first.value : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: activeVal,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F172A),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(ImportedTask task, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isSelected 
              ? const Color(0xFF3B82F6).withOpacity(0.3)
              : Colors.white.withOpacity(0.03),
          width: 1,
        ),
        gradient: LinearGradient(
          colors: [
            task.isSelected 
                ? const Color(0xFF1E293B).withOpacity(0.8)
                : const Color(0xFF1E293B).withOpacity(0.3),
            task.isSelected
                ? const Color(0xFF0F172A).withOpacity(0.9)
                : const Color(0xFF0F172A).withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isSelected,
            activeColor: const Color(0xFF3B82F6),
            onChanged: (val) {
              setState(() {
                task.isSelected = val ?? true;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: task.subject,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    labelStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
                  ),
                  onChanged: (val) {
                    task.subject = val;
                  },
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: task.day,
                            isDense: true,
                            dropdownColor: const Color(0xFF0F172A),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                                .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                task.day = val ?? 'Monday';
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        initialValue: task.endTime != null ? '${task.startTime} - ${task.endTime}' : task.startTime,
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Time Range (e.g. 7-8 PM)',
                          hintStyle: TextStyle(color: Color(0xFF475569)),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
                        ),
                        onChanged: (val) {
                          final range = TimetableParser.parseTimeRange(val);
                          task.startTime = range['start'] ?? val;
                          task.endTime = (range['end'] ?? '').isNotEmpty ? range['end'] : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildSmallBadge(Icons.repeat_rounded, 'Weekly', const Color(0xFF10B981)),
                    _buildSmallBadge(Icons.alarm_on_rounded, 'Alarm', const Color(0xFFF59E0B)),
                    _buildSmallBadge(Icons.star_rounded, '50 XP', const Color(0xFF8B5CF6)),
                    _buildSmallBadge(Icons.monetization_on_rounded, '20 Coins', const Color(0xFFD97706)),
                    _buildSmallBadge(Icons.priority_high_rounded, 'Medium', const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
