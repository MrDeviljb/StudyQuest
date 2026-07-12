import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

enum TimetableLayoutType {
  list,
  gridDaysHeader,    // Days on top, Time on left
  gridTimesHeader,   // Time on top, Days on left
  unknown
}

class ImportedTask {
  String subject;
  String day;
  String startTime;
  String? endTime;
  bool isSelected;

  ImportedTask({
    required this.subject,
    required this.day,
    required this.startTime,
    this.endTime,
    this.isSelected = true,
  });

  ImportedTask copyWith({
    String? subject,
    String? day,
    String? startTime,
    String? endTime,
    bool? isSelected,
  }) {
    return ImportedTask(
      subject: subject ?? this.subject,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  String toString() => '$day | $startTime-${endTime ?? ""} | $subject';
}

class TimetableParseResult {
  final bool isSuccess;
  final double confidenceScore;
  final TimetableLayoutType layoutType;
  final Map<String, List<List<String>>> allSheets;
  final String selectedSheet;
  final int? dayIdx;
  final int? timeIdx;
  final int? subjectIdx;
  final List<ImportedTask> parsedTasks;
  final String? errorMessage;

  TimetableParseResult({
    required this.isSuccess,
    required this.confidenceScore,
    required this.layoutType,
    required this.allSheets,
    required this.selectedSheet,
    this.dayIdx,
    this.timeIdx,
    this.subjectIdx,
    required this.parsedTasks,
    this.errorMessage,
  });
}

class SpannedRange {
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;

  SpannedRange(this.startRow, this.startCol, this.endRow, this.endCol);

  bool contains(int r, int c) {
    return r >= startRow && r <= endRow && c >= startCol && c <= endCol;
  }
}

class TimetableParser {
  // Parse XLSX/XLS bytes
  static TimetableParseResult parseExcel(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return _makeEmptyResult('No sheets found in Excel file.');
      }

      final Map<String, List<List<String>>> allSheets = {};
      final Map<String, List<SpannedRange>> sheetSpans = {};

      for (var sheetName in excel.tables.keys) {
        final table = excel.tables[sheetName]!;
        final List<List<String>> rows = [];
        
        // Build spanned ranges for this sheet
        final spans = _getSpannedRanges(table);
        sheetSpans[sheetName] = spans;

        for (int r = 0; r < table.maxRows; r++) {
          final List<String> rowCells = [];
          for (int c = 0; c < table.maxColumns; c++) {
            rowCells.add(_getCellValue(table, spans, r, c));
          }
          // Only add rows that have at least one non-empty value
          if (rowCells.any((cell) => cell.isNotEmpty)) {
            rows.add(rowCells);
          }
        }
        if (rows.isNotEmpty) {
          allSheets[sheetName] = rows;
        }
      }

      if (allSheets.isEmpty) {
        return _makeEmptyResult('Excel sheets are empty.');
      }

      // Choose the sheet most likely to be a timetable
      String bestSheet = allSheets.keys.first;
      double highestScore = -1.0;
      for (var entry in allSheets.entries) {
        final score = _calculateTimetableLikelihood(entry.value);
        if (score > highestScore) {
          highestScore = score;
          bestSheet = entry.key;
        }
      }

      // Parse the selected sheet
      return parseSheet(allSheets, bestSheet);
    } catch (e) {
      return _makeEmptyResult('Failed to parse Excel: $e');
    }
  }

  // Parse CSV bytes
  static TimetableParseResult parseCsv(List<int> bytes) {
    try {
      final csvString = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n');
      final fields = const CsvToListConverter(eol: '\n').convert(csvString);

      final List<List<String>> rows = fields.map((row) {
        return row.map((cell) => cell?.toString().trim() ?? '').toList();
      }).where((row) => row.any((c) => c.isNotEmpty)).toList();

      if (rows.isEmpty) {
        return _makeEmptyResult('CSV is empty.');
      }

      final Map<String, List<List<String>>> allSheets = {'CSV': rows};
      return parseSheet(allSheets, 'CSV');
    } catch (e) {
      return _makeEmptyResult('Failed to parse CSV: $e');
    }
  }

  // Parse a specific sheet from the sheets map
  static TimetableParseResult parseSheet(Map<String, List<List<String>>> allSheets, String sheetName) {
    final rows = allSheets[sheetName] ?? [];
    if (rows.isEmpty) {
      return _makeEmptyResult('Sheet is empty.');
    }

    // Try auto-detecting layout
    return _detectAndParse(allSheets, sheetName, rows);
  }

  // Core layout detection and parsing
  static TimetableParseResult _detectAndParse(
      Map<String, List<List<String>>> allSheets, String sheetName, List<List<String>> rows) {
    
    // We scan rows up to index 15 to find the header row candidates
    int maxScanRows = rows.length < 15 ? rows.length : 15;

    int? bestHeaderIdx;
    TimetableLayoutType detectedLayout = TimetableLayoutType.unknown;
    double maxConfidence = 0.0;
    
    int? dayIdx;
    int? timeIdx;
    int? subjectIdx;

    final weekdays = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};

    for (int r = 0; r < maxScanRows; r++) {
      final row = rows[r];

      // 1. Check List Layout
      int dIdx = -1;
      int tIdx = -1;
      int sIdx = -1;

      for (int c = 0; c < row.length; c++) {
        final val = row[c].toLowerCase().trim();
        if (val == 'day' || val == 'weekday') dIdx = c;
        if (val == 'time' || val == 'start time' || val == 'timing' || val == 'duration') tIdx = c;
        if (val == 'task' || val == 'subject' || val == 'course' || val == 'class' || val == 'lecture') sIdx = c;
      }

      // Try fallback contains if exact headers not found
      if (dIdx == -1 || tIdx == -1 || sIdx == -1) {
        int dTemp = -1;
        int tTemp = -1;
        int sTemp = -1;
        for (int c = 0; c < row.length; c++) {
          final val = row[c].toLowerCase().trim();
          if (dTemp == -1 && (val.contains('day') || val.contains('weekday'))) dTemp = c;
          if (tTemp == -1 && (val.contains('time') || val.contains('timing') || val.contains('duration'))) tTemp = c;
          if (sTemp == -1 && (val.contains('task') || val.contains('subject') || val.contains('course') || val.contains('class') || val.contains('lecture'))) sTemp = c;
        }
        if (dIdx == -1) dIdx = dTemp;
        if (tIdx == -1) tIdx = tTemp;
        if (sIdx == -1) sIdx = sTemp;
      }

      if (dIdx != -1 && tIdx != -1 && sIdx != -1) {
        // List Layout matched
        double confidence = 0.95;
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          detectedLayout = TimetableLayoutType.list;
          bestHeaderIdx = r;
          dayIdx = dIdx;
          timeIdx = tIdx;
          subjectIdx = sIdx;
        }
      }

      // 2. Check Grid Days Header Layout (Days on Top, Time on Left)
      int weekdayCount = 0;
      for (var cell in row) {
        final val = cell.toLowerCase().trim();
        if (weekdays.contains(val)) weekdayCount++;
      }

      if (weekdayCount >= 3) {
        // Find which column has times
        int tCol = -1;
        // Search columns for time formats in subsequent rows
        for (int col = 0; col < row.length; col++) {
          int timeCells = 0;
          for (int checkR = r + 1; checkR < rows.length && checkR < r + 6; checkR++) {
            if (col < rows[checkR].length && _isTimeString(rows[checkR][col])) {
              timeCells++;
            }
          }
          if (timeCells >= 2) {
            tCol = col;
            break;
          }
        }

        // If time column is found or default col 0
        if (tCol == -1 && row.isNotEmpty) tCol = 0;

        double confidence = 0.95;
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          detectedLayout = TimetableLayoutType.gridDaysHeader;
          bestHeaderIdx = r;
          dayIdx = r; // Header row index is the day index
          timeIdx = tCol;
          subjectIdx = null; // grid entries are subject
        }
      }

      // 3. Check Grid Times Header Layout (Time on Top, Days on Left)
      int timeCount = 0;
      for (var cell in row) {
        if (_isTimeString(cell)) timeCount++;
      }

      if (timeCount >= 2) {
        // Find Day column
        int dCol = -1;
        for (int col = 0; col < row.length; col++) {
          int dayCells = 0;
          for (int checkR = r + 1; checkR < rows.length && checkR < r + 6; checkR++) {
            if (col < rows[checkR].length) {
              final val = rows[checkR][col].toLowerCase().trim();
              if (weekdays.contains(val)) dayCells++;
            }
          }
          if (dayCells >= 2) {
            dCol = col;
            break;
          }
        }
        if (dCol == -1 && row.isNotEmpty) dCol = 0;

        double confidence = 0.90;
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          detectedLayout = TimetableLayoutType.gridTimesHeader;
          bestHeaderIdx = r;
          dayIdx = dCol;
          timeIdx = r; // Row header contains times
          subjectIdx = null;
        }
      }
    }

    // Default Fallback
    if (detectedLayout == TimetableLayoutType.unknown) {
      detectedLayout = TimetableLayoutType.list;
      bestHeaderIdx = 0;
      dayIdx = 0;
      timeIdx = 1 < (rows.first.length) ? 1 : 0;
      subjectIdx = 2 < (rows.first.length) ? 2 : 0;
      maxConfidence = 0.50; // low confidence opens the wizard
    }

    // Parse the tasks based on the detected parameters
    final List<ImportedTask> tasks = parseTasks(rows, detectedLayout, bestHeaderIdx!, dayIdx!, timeIdx!, subjectIdx);

    return TimetableParseResult(
      isSuccess: true,
      confidenceScore: maxConfidence,
      layoutType: detectedLayout,
      allSheets: allSheets,
      selectedSheet: sheetName,
      dayIdx: dayIdx,
      timeIdx: timeIdx,
      subjectIdx: subjectIdx,
      parsedTasks: tasks,
    );
  }

  // Parse tasks given a layout and indices
  static List<ImportedTask> parseTasks(
      List<List<String>> rows,
      TimetableLayoutType layout,
      int headerIdx,
      int dayIdx,
      int timeIdx,
      int? subjectIdx) {
    
    final List<ImportedTask> tasks = [];
    final sectionKeywords = {'daily habit', 'weekly targets', 'notes', 'summary', 'weekly target'};

    if (layout == TimetableLayoutType.list) {
      // List parsing
      for (int r = headerIdx + 1; r < rows.length; r++) {
        final row = rows[r];

        bool isDayEmpty = dayIdx >= row.length || row[dayIdx].trim().isEmpty;
        bool isTimeEmpty = timeIdx >= row.length || row[timeIdx].trim().isEmpty;
        bool isSubjectEmpty = subjectIdx == null || subjectIdx >= row.length || row[subjectIdx].trim().isEmpty;

        if (isDayEmpty && isTimeEmpty && isSubjectEmpty) {
          break; // stop reading when all columns are empty
        }

        // Section filter
        bool isSection = false;
        for (var cell in row) {
          final cellVal = cell.trim().toLowerCase();
          if (sectionKeywords.any((kw) => cellVal == kw || cellVal.startsWith('$kw:'))) {
            isSection = true;
            break;
          }
        }
        if (isSection) continue;

        final dayVal = dayIdx < row.length ? row[dayIdx].trim() : '';
        final timeVal = timeIdx < row.length ? row[timeIdx].trim() : '';
        final subjectVal = (subjectIdx != null && subjectIdx < row.length) ? row[subjectIdx].trim() : '';

        if (subjectVal.isEmpty) continue;
        if (!_isWeekdayString(dayVal)) continue; // skip non-weekday rows

        final range = parseTimeRange(timeVal);
        tasks.add(ImportedTask(
          subject: subjectVal,
          day: _normalizeDay(dayVal),
          startTime: range['start'] ?? timeVal,
          endTime: range['end'],
        ));
      }
    } else if (layout == TimetableLayoutType.gridDaysHeader) {
      // Days on Top (Columns), Time on Left (Column)
      final headerRow = rows[headerIdx];

      for (int r = headerIdx + 1; r < rows.length; r++) {
        final row = rows[r];

        bool isTimeEmpty = timeIdx >= row.length || row[timeIdx].trim().isEmpty;
        if (isTimeEmpty) continue;

        // Skip section divider
        bool isSection = false;
        for (var cell in row) {
          final cellVal = cell.trim().toLowerCase();
          if (sectionKeywords.any((kw) => cellVal == kw || cellVal.startsWith('$kw:'))) {
            isSection = true;
            break;
          }
        }
        if (isSection) continue;

        final timeVal = row[timeIdx].trim();
        final range = parseTimeRange(timeVal);

        for (int c = 0; c < row.length; c++) {
          if (c == timeIdx) continue;
          if (c >= headerRow.length) continue;

          final dayVal = headerRow[c].trim();
          if (!_isWeekdayString(dayVal)) continue;

          final subjectVal = row[c].trim();
          if (subjectVal.isEmpty) continue;

          tasks.add(ImportedTask(
            subject: subjectVal,
            day: _normalizeDay(dayVal),
            startTime: range['start'] ?? timeVal,
            endTime: range['end'],
          ));
        }
      }
    } else if (layout == TimetableLayoutType.gridTimesHeader) {
      // Time on Top (Columns), Days on Left (Column)
      final headerRow = rows[headerIdx];

      for (int r = headerIdx + 1; r < rows.length; r++) {
        final row = rows[r];

        bool isDayEmpty = dayIdx >= row.length || row[dayIdx].trim().isEmpty;
        if (isDayEmpty) continue;

        // Skip section divider
        bool isSection = false;
        for (var cell in row) {
          final cellVal = cell.trim().toLowerCase();
          if (sectionKeywords.any((kw) => cellVal == kw || cellVal.startsWith('$kw:'))) {
            isSection = true;
            break;
          }
        }
        if (isSection) continue;

        final dayVal = row[dayIdx].trim();
        if (!_isWeekdayString(dayVal)) continue;

        for (int c = 0; c < row.length; c++) {
          if (c == dayIdx) continue;
          if (c >= headerRow.length) continue;

          final timeVal = headerRow[c].trim();
          if (!_isTimeString(timeVal)) continue;

          final subjectVal = row[c].trim();
          if (subjectVal.isEmpty) continue;

          final range = parseTimeRange(timeVal);

          tasks.add(ImportedTask(
            subject: subjectVal,
            day: _normalizeDay(dayVal),
            startTime: range['start'] ?? timeVal,
            endTime: range['end'],
          ));
        }
      }
    }

    return mergeSequentialTasks(tasks);
  }

  // Merge adjacent sequential tasks of the same subject on the same day
  static List<ImportedTask> mergeSequentialTasks(List<ImportedTask> tasks) {
    if (tasks.length <= 1) return tasks;

    // Group by Day and Subject
    final Map<String, List<ImportedTask>> grouped = {};
    for (var task in tasks) {
      final key = '${task.day.toLowerCase()}_${task.subject.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final List<ImportedTask> mergedTasks = [];

    for (var list in grouped.values) {
      if (list.length == 1) {
        mergedTasks.add(list.first);
        continue;
      }

      // Sort by start time minutes
      list.sort((a, b) => _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime)));

      ImportedTask current = list.first;
      for (int i = 1; i < list.length; i++) {
        final next = list[i];

        final currentEnd = _timeToMinutes(current.endTime ?? current.startTime);
        final nextStart = _timeToMinutes(next.startTime);

        // If they touch or overlap, merge them (within a 15-minute gap range)
        if (nextStart >= currentEnd - 5 && nextStart <= currentEnd + 15) {
          current = current.copyWith(
            endTime: next.endTime ?? next.startTime,
          );
        } else {
          mergedTasks.add(current);
          current = next;
        }
      }
      mergedTasks.add(current);
    }

    // Sort the final tasks list chronologically for a neat preview
    final dayOrder = {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7};
    mergedTasks.sort((a, b) {
      final dayA = dayOrder[a.day.toLowerCase()] ?? 8;
      final dayB = dayOrder[b.day.toLowerCase()] ?? 8;
      if (dayA != dayB) return dayA.compareTo(dayB);
      return _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime));
    });

    return mergedTasks;
  }

  // Helper: parses time range from format like "7:00–8:30 PM"
  static Map<String, String> parseTimeRange(String timeStr) {
    timeStr = timeStr.trim();
    // Split by dashes, hyphens, or 'to'
    final parts = timeStr.split(RegExp(r'\s*(?:[-–—]|to)\s*', caseSensitive: false));
    if (parts.isEmpty) {
      return {'start': '', 'end': ''};
    }

    String start = parts[0].trim();
    String end = parts.length > 1 ? parts[1].trim() : '';

    final amPmRegex = RegExp(r'(am|pm)', caseSensitive: false);
    final startHasAmPm = amPmRegex.hasMatch(start);
    final endHasAmPm = amPmRegex.hasMatch(end);

    // If start time does not have AM/PM, but end time does, inherit it (accounting for noon transition)
    if (!startHasAmPm && endHasAmPm) {
      final match = amPmRegex.firstMatch(end);
      if (match != null) {
        final amPm = match.group(0)!;
        final startHourMatch = RegExp(r'^(\d{1,2})').firstMatch(start);
        final endHourMatch = RegExp(r'^(\d{1,2})').firstMatch(end);
        if (startHourMatch != null && endHourMatch != null) {
          final startHour = int.tryParse(startHourMatch.group(1)!) ?? 0;
          final endHour = int.tryParse(endHourMatch.group(1)!) ?? 0;
          if (amPm.toLowerCase() == 'pm' && startHour > endHour && startHour != 12) {
            start = '$start AM';
          } else {
            start = '$start $amPm';
          }
        } else {
          start = '$start $amPm';
        }
      }
    }

    // Formatting checks to ensure output times are clean (e.g. "07:00" -> "7:00 AM" if missing AM/PM)
    start = _formatTimeString(start);
    if (end.isNotEmpty) {
      end = _formatTimeString(end);
    }

    return {'start': start, 'end': end.isNotEmpty ? end : ''};
  }

  static String _formatTimeString(String timeStr) {
    timeStr = timeStr.trim().toUpperCase();
    final timeOnly = timeStr.replaceAll(RegExp(r'[A-Z\s]'), '');
    final amPmRegex = RegExp(r'(AM|PM)');
    final match = amPmRegex.firstMatch(timeStr);
    String amPm = match != null ? match.group(0)! : '';

    final parts = timeOnly.split(':');
    if (parts.isEmpty) return timeStr;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Convert 24 hour to 12 hour if AM/PM is empty
    if (amPm.isEmpty) {
      if (hour >= 12) {
        amPm = 'PM';
        if (hour > 12) hour -= 12;
      } else {
        amPm = 'AM';
        if (hour == 0) hour = 12;
      }
    }

    final minStr = minute < 10 ? '0$minute' : '$minute';
    return '$hour:$minStr $amPm';
  }

  static int _timeToMinutes(String timeStr) {
    timeStr = timeStr.toLowerCase().trim();
    final isPm = timeStr.contains('pm');
    final isAm = timeStr.contains('am');

    final cleanTime = timeStr.replaceAll(RegExp(r'[a-z\s]'), '');
    final parts = cleanTime.split(':');
    if (parts.isEmpty) return 0;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (isPm && hour != 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  static bool _isTimeString(String cellVal) {
    cellVal = cellVal.toLowerCase().trim();
    if (cellVal.isEmpty) return false;
    // Matches hours like 7 PM, 7:00, 19:00, 7-8 PM, 07:00-08:30 etc.
    final timeRegex = RegExp(r'\d{1,2}(:\d{2})?\s*(am|pm)?', caseSensitive: false);
    return timeRegex.hasMatch(cellVal) && cellVal.contains(RegExp(r'\d'));
  }

  static bool _isWeekdayString(String cellVal) {
    cellVal = cellVal.toLowerCase().trim();
    final weekdays = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};
    return weekdays.contains(cellVal) || weekdays.any((day) => cellVal.startsWith(day));
  }

  static String _normalizeDay(String dayVal) {
    final v = dayVal.toLowerCase().trim();
    if (v.contains('mon')) return 'Monday';
    if (v.contains('tue')) return 'Tuesday';
    if (v.contains('wed')) return 'Wednesday';
    if (v.contains('thu')) return 'Thursday';
    if (v.contains('fri')) return 'Friday';
    if (v.contains('sat')) return 'Saturday';
    if (v.contains('sun')) return 'Sunday';
    return 'Monday';
  }

  // Calculate likelihood of a sheet being a timetable
  static double _calculateTimetableLikelihood(List<List<String>> rows) {
    if (rows.isEmpty) return 0.0;
    double score = 0.0;

    final weekdays = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};
    final docKeywords = {'timetable', 'schedule', 'planner', 'subject', 'class', 'lecture', 'course', 'task', 'time', 'day'};

    int cellCount = 0;
    int dayCount = 0;
    int timeCount = 0;
    int keywordCount = 0;

    for (int r = 0; r < rows.length && r < 30; r++) {
      for (var cell in rows[r]) {
        cellCount++;
        final val = cell.toLowerCase().trim();
        if (val.isEmpty) continue;

        if (weekdays.contains(val)) dayCount++;
        if (_isTimeString(val)) timeCount++;

        for (var kw in docKeywords) {
          if (val.contains(kw)) keywordCount++;
        }
      }
    }

    if (cellCount == 0) return 0.0;

    score += dayCount * 4.0;
    score += timeCount * 3.0;
    score += keywordCount * 1.0;

    return score;
  }

  // Build spanned cell ranges for resolving merged cell values
  static List<SpannedRange> _getSpannedRanges(Sheet sheet) {
    final List<SpannedRange> ranges = [];
    for (var spanned in sheet.spannedItems) {
      String rangeStr = spanned.toString();
      if (rangeStr.contains('!')) {
        rangeStr = rangeStr.split('!').last;
      }
      final parts = rangeStr.split(':');
      if (parts.length == 2) {
        final start = _parseCellCoordinate(parts[0]);
        final end = _parseCellCoordinate(parts[1]);
        ranges.add(SpannedRange(start[0], start[1], end[0], end[1]));
      }
    }
    return ranges;
  }

  // Resolves value of a cell, returning top-left cell value if inside a merged cell
  static String _getCellValue(Sheet sheet, List<SpannedRange> ranges, int r, int c) {
    for (var range in ranges) {
      if (range.contains(r, c)) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: range.startCol, rowIndex: range.startRow));
        return cell.value?.toString().trim() ?? '';
      }
    }
    if (r < sheet.maxRows && c < sheet.maxColumns) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      return cell.value?.toString().trim() ?? '';
    }
    return '';
  }

  // Converts coordinate like "A1" or "C5" to [row, col] indices (0-based)
  static List<int> _parseCellCoordinate(String coord) {
    coord = coord.toUpperCase().trim();
    final letters = RegExp(r'[A-Z]+').stringMatch(coord) ?? '';
    final numbers = RegExp(r'[0-9]+').stringMatch(coord) ?? '';

    int col = 0;
    for (int i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 65 + 1);
    }
    col = col - 1; // 0-based

    int row = (int.tryParse(numbers) ?? 1) - 1; // 0-based
    return [row, col];
  }

  // Create an empty success = false parse result
  static TimetableParseResult _makeEmptyResult(String message) {
    return TimetableParseResult(
      isSuccess: false,
      confidenceScore: 0.0,
      layoutType: TimetableLayoutType.unknown,
      allSheets: {},
      selectedSheet: '',
      parsedTasks: [],
      errorMessage: message,
    );
  }
}
