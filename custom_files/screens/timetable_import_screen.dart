import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../task_provider.dart';
import '../task_model.dart';
import '../timetable_parser.dart';
import '../alarm_service.dart';

class TimetableImportScreen extends StatefulWidget {
  const TimetableImportScreen({Key? key}) : super(key: key);

  @override
  State<TimetableImportScreen> createState() => _TimetableImportScreenState();
}

class _TimetableImportScreenState extends State<TimetableImportScreen> {
  bool _isParsing = false;
  TimetableParseResult? _parseResult;
  String? _fileName;

  // Selected column indices (either auto-detected or manual)
  int? _selectedDayCol;
  int? _selectedSubjectCol;
  int? _selectedStartCol;
  int? _selectedEndCol;

  Future<void> _pickAndParseFile() async {
    setState(() {
      _isParsing = true;
      _parseResult = null;
      _fileName = null;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _fileName = file.name;
        final bytes = file.bytes;

        if (bytes != null) {
          TimetableParseResult parseData;
          if (file.extension == 'xlsx') {
            parseData = TimetableParser.parseExcel(bytes);
          } else {
            parseData = TimetableParser.parseCsv(bytes);
          }

          setState(() {
            _parseResult = parseData;
            if (parseData.isSuccess) {
              _selectedDayCol = parseData.dayColIdx;
              _selectedSubjectCol = parseData.subjectColIdx;
              _selectedStartCol = parseData.startTimeColIdx;
              _selectedEndCol = parseData.endTimeColIdx;
            } else {
              // initialize dropdowns to sensible defaults if auto-detect fails
              _selectedDayCol = 0;
              _selectedSubjectCol = 1 < parseData.rows.first.length ? 1 : 0;
              _selectedStartCol = 2 < parseData.rows.first.length ? 2 : 0;
              _selectedEndCol = 3 < parseData.rows.first.length ? 3 : 0;
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  // Find the next occurrence of a given weekday
  DateTime _getNextWeekday(String dayName) {
    final now = DateTime.now();
    final dName = dayName.toLowerCase();
    
    int targetDay = DateTime.monday;
    if (dName.startsWith('mon')) targetDay = DateTime.monday;
    else if (dName.startsWith('tue')) targetDay = DateTime.tuesday;
    else if (dName.startsWith('wed')) targetDay = DateTime.wednesday;
    else if (dName.startsWith('thu')) targetDay = DateTime.thursday;
    else if (dName.startsWith('fri')) targetDay = DateTime.friday;
    else if (dName.startsWith('sat')) targetDay = DateTime.saturday;
    else if (dName.startsWith('sun')) targetDay = DateTime.sunday;

    int daysToAdd = targetDay - now.weekday;
    if (daysToAdd <= 0) daysToAdd += 7; // force future occurrence
    return now.add(Duration(days: daysToAdd));
  }

  void _saveTimetableTasks() async {
    if (_parseResult == null ||
        _selectedDayCol == null ||
        _selectedSubjectCol == null ||
        _selectedStartCol == null) {
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final rows = _parseResult!.rows;
    int tasksCreated = 0;

    // Skip the header row
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length <= _selectedDayCol! ||
          row.length <= _selectedSubjectCol! ||
          row.length <= _selectedStartCol!) {
        continue;
      }

      final dayVal = row[_selectedDayCol!];
      final subjectVal = row[_selectedSubjectCol!];
      final startVal = row[_selectedStartCol!];
      final endVal = (_selectedEndCol != null && _selectedEndCol! < row.length)
          ? row[_selectedEndCol!]
          : null;

      if (dayVal.isEmpty || subjectVal.isEmpty || startVal.isEmpty) continue;

      // Hash color mapping from subject name
      final colorList = ['#8B5CF6', '#EC4899', '#3B82F6', '#10B981', '#F59E0B', '#EF4444'];
      final colorHex = colorList[subjectVal.hashCode.abs() % colorList.length];

      final targetDate = _getNextWeekday(dayVal);

      final task = Task(
        id: 'timetable_${DateTime.now().microsecondsSinceEpoch}_$r',
        title: 'Study: $subjectVal',
        description: 'Auto-imported from timetable on $dayVal',
        subject: subjectVal,
        date: targetDate,
        startTime: startVal,
        endTime: endVal,
        priority: 1, // Medium
        repeat: 'weekly', // Every Monday, etc.
        reminderMinutesBefore: 10, // 10 minutes reminder
        completed: false,
        xpReward: 50,
        coinReward: 15,
        notes: 'Timetable Import',
        colorHex: colorHex,
        category: 'Study Session',
      );

      await taskProvider.addTask(task);
      await AlarmService.scheduleAlarm(task);
      tasksCreated++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported $tasksCreated weekly tasks!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _parseResult != null && _parseResult!.rows.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Importer'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('📂', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Excel or CSV',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Our parser will identify columns to build your weekly repeating schedule.',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Upload Button / Status
              if (_isParsing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (!hasData)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickAndParseFile,
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('Select Timetable File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Parsed file: $_fileName',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // AI Detection Alert Status
                    if (_parseResult!.isSuccess)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B15),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Text('✅', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text(
                              'Timetable structure detected automatically!',
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1515),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Text('⚠️', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto-detection failed. Please map the columns manually below.',
                                style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 24),

              // Mapping Controls & Previews if data loaded
              if (hasData) ...[
                const Text(
                  'Map Timetable Columns',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 12),
                _buildMappingDropdowns(_parseResult!.rows.first),
                const SizedBox(height: 24),

                const Text(
                  'Timetable Preview Rows',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFF1E293B)),
                            columns: List.generate(
                              _parseResult!.rows.first.length,
                              (idx) => DataColumn(
                                label: Text(
                                  _parseResult!.rows.first[idx],
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ),
                            ),
                            rows: _parseResult!.rows
                                .skip(1)
                                .take(8)
                                .map(
                                  (row) => DataRow(
                                    cells: List.generate(
                                      row.length,
                                      (idx) => DataCell(Text(row[idx])),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                ElevatedButton(
                  onPressed: _saveTimetableTasks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Generate Timetable Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMappingDropdowns(List<String> headers) {
    Widget buildDropdown(String label, int? currentValue, Function(int?) onChanged) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: currentValue,
              dropdownColor: const Color(0xFF16161A),
              underline: const SizedBox(),
              items: List.generate(
                headers.length,
                (idx) => DropdownMenuItem(
                  value: idx,
                  child: Text('Col $idx: ${headers[idx].take(10)}'),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          buildDropdown('Day Column (e.g. Monday):', _selectedDayCol, (val) {
            setState(() => _selectedDayCol = val);
          }),
          const Divider(color: Colors.white10),
          buildDropdown('Subject Column (e.g. Course):', _selectedSubjectCol, (val) {
            setState(() => _selectedSubjectCol = val);
          }),
          const Divider(color: Colors.white10),
          buildDropdown('Start Time Column:', _selectedStartCol, (val) {
            setState(() => _selectedStartCol = val);
          }),
          const Divider(color: Colors.white10),
          buildDropdown('End Time Column (Optional):', _selectedEndCol, (val) {
            setState(() => _selectedEndCol = val);
          }),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String take(int count) {
    if (length <= count) return this;
    return '${substring(0, count)}...';
  }
}
