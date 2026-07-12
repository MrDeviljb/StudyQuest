import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

class TimetableParseResult {
  final bool isSuccess;
  final int? dayColIdx;
  final int? subjectColIdx;
  final int? startTimeColIdx;
  final int? endTimeColIdx;
  final List<List<String>> rows;
  final String? errorMessage;

  TimetableParseResult({
    required this.isSuccess,
    this.dayColIdx,
    this.subjectColIdx,
    this.startTimeColIdx,
    this.endTimeColIdx,
    required this.rows,
    this.errorMessage,
  });
}

class TimetableParser {
  // Parse XLSX bytes
  static TimetableParseResult parseExcel(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return TimetableParseResult(isSuccess: false, rows: [], errorMessage: 'No sheets found in Excel file.');
      }
      
      // Use the first sheet
      final sheetName = excel.tables.keys.first;
      final table = excel.tables[sheetName]!;
      
      final List<List<String>> rows = [];
      for (var row in table.rows) {
        final List<String> rowCells = row.map((cell) => cell?.value?.toString().trim() ?? '').toList();
        // check if row is completely empty
        if (rowCells.any((c) => c.isNotEmpty)) {
          rows.add(rowCells);
        }
      }

      if (rows.isEmpty) {
        return TimetableParseResult(isSuccess: false, rows: [], errorMessage: 'Excel sheet is empty.');
      }

      return _analyzeColumns(rows);
    } catch (e) {
      return TimetableParseResult(isSuccess: false, rows: [], errorMessage: 'Failed to parse Excel: $e');
    }
  }

  // Parse CSV bytes
  static TimetableParseResult parseCsv(List<int> bytes) {
    try {
      final csvString = utf8.decode(bytes, allowMalformed: true);
      final fields = const CsvToListConverter().convert(csvString);
      
      final List<List<String>> rows = fields.map((row) {
        return row.map((cell) => cell?.toString().trim() ?? '').toList();
      }).where((row) => row.any((c) => c.isNotEmpty)).toList();

      if (rows.isEmpty) {
        return TimetableParseResult(isSuccess: false, rows: [], errorMessage: 'CSV is empty.');
      }

      return _analyzeColumns(rows);
    } catch (e) {
      return TimetableParseResult(isSuccess: false, rows: [], errorMessage: 'Failed to parse CSV: $e');
    }
  }

  // Heuristic AI Column detection
  static TimetableParseResult _analyzeColumns(List<List<String>> rows) {
    final headerRow = rows.first;
    int? dayIdx;
    int? subjectIdx;
    int? startIdx;
    int? endIdx;

    // Helper functions for matching
    bool matchDay(String header, String cellSample) {
      final h = header.toLowerCase();
      final c = cellSample.toLowerCase();
      final dayHeaders = ['day', 'date', 'weekday', 'schedule', 'timetable'];
      final dayValues = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      
      if (dayHeaders.any((dh) => h.contains(dh))) return true;
      if (dayValues.any((dv) => c == dv || c.startsWith(dv))) return true;
      return false;
    }

    bool matchTime(String header, String cellSample, bool isEnd) {
      final h = header.toLowerCase();
      final c = cellSample.toLowerCase();
      
      // Look for explicit start/end triggers
      if (isEnd) {
        if (h.contains('end') || h.contains('to') || h.contains('until') || h.contains('stop')) return true;
      } else {
        if (h.contains('start') || h.contains('from') || h.contains('begin') || h.contains('time')) return true;
      }

      // Check format (e.g. contains numbers and colon, or AM/PM)
      final timeRegex = RegExp(r'\d{1,2}(:\d{2})?\s*(am|pm|pm|am|clock|gmt)?', caseSensitive: false);
      if (timeRegex.hasMatch(c)) {
        // If there are two time columns, start usually comes first
        return true;
      }
      return false;
    }

    bool matchSubject(String header, String cellSample) {
      final h = header.toLowerCase();
      final subjectHeaders = ['subject', 'course', 'class', 'module', 'lecture', 'topic', 'title', 'study', 'unit'];
      if (subjectHeaders.any((sh) => h.contains(sh))) return true;
      
      // General fallbacks: non-empty text, not matching days or times
      final timeRegex = RegExp(r'\d', caseSensitive: false);
      final isDayVal = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].any((d) => cellSample.toLowerCase().startsWith(d));
      
      if (cellSample.isNotEmpty && !timeRegex.hasMatch(cellSample) && !isDayVal) {
        return true;
      }
      return false;
    }

    // Try detecting columns by scanning row headers and samples (first 3 rows)
    int columnsCount = headerRow.length;
    List<double> dayConf = List.filled(columnsCount, 0.0);
    List<double> subjectConf = List.filled(columnsCount, 0.0);
    List<double> startConf = List.filled(columnsCount, 0.0);
    List<double> endConf = List.filled(columnsCount, 0.0);

    for (int col = 0; col < columnsCount; col++) {
      String header = headerRow[col];
      
      // check next few rows for samples
      int samplesScanned = 0;
      for (int r = 1; r < rows.length && r < 5; r++) {
        if (col < rows[r].length) {
          String sample = rows[r][col];
          samplesScanned++;

          if (matchDay(header, sample)) dayConf[col] += 1.0;
          if (matchSubject(header, sample)) subjectConf[col] += 1.0;
          if (matchTime(header, sample, false)) startConf[col] += 1.0;
          if (matchTime(header, sample, true)) endConf[col] += 1.0;
        }
      }
      
      // Normalize confidence
      if (samplesScanned > 0) {
        dayConf[col] /= samplesScanned;
        subjectConf[col] /= samplesScanned;
        startConf[col] /= samplesScanned;
        endConf[col] /= samplesScanned;
      }
      
      // Add weight to header matches
      final h = header.toLowerCase();
      if (h.contains('day') || h.contains('date')) dayConf[col] += 0.5;
      if (h.contains('subject') || h.contains('course') || h.contains('class') || h.contains('module')) subjectConf[col] += 0.5;
      if (h.contains('start') || h.contains('from')) startConf[col] += 0.5;
      if (h.contains('end') || h.contains('to')) endConf[col] += 0.5;
    }

    // Find highest confidences
    double maxDayVal = -1.0;
    double maxSubVal = -1.0;
    double maxStartVal = -1.0;
    double maxEndVal = -1.0;

    for (int c = 0; c < columnsCount; c++) {
      if (dayConf[c] > maxDayVal && dayConf[c] >= 0.5) {
        maxDayVal = dayConf[c];
        dayIdx = c;
      }
      if (subjectConf[c] > maxSubVal && subjectConf[c] >= 0.5) {
        maxSubVal = subjectConf[c];
        subjectIdx = c;
      }
      if (startConf[c] > maxStartVal && startConf[c] >= 0.5) {
        maxStartVal = startConf[c];
        startIdx = c;
      }
      if (endConf[c] > maxEndVal && endConf[c] >= 0.5) {
        maxEndVal = endConf[c];
        endIdx = c;
      }
    }

    // Resolve overlaps (e.g. if start time and end time confidences point to same column)
    if (startIdx != null && endIdx != null && startIdx == endIdx) {
      // Typically, start is before end. So if there is another column matching time, allocate properly
      double secondBestStart = -1.0;
      int? secondStartIdx;
      for (int c = 0; c < columnsCount; c++) {
        if (c != startIdx && startConf[c] > secondBestStart) {
          secondBestStart = startConf[c];
          secondStartIdx = c;
        }
      }
      // Reassign if valid
      if (secondStartIdx != null && secondStartIdx < startIdx) {
        startIdx = secondStartIdx;
      } else {
        // usually start column is left of end column
        // look for columns near startIdx
        if (startIdx + 1 < columnsCount) {
          endIdx = startIdx + 1;
        }
      }
    }

    // Check if we detected everything confidently
    bool confidenceSuccess = dayIdx != null && subjectIdx != null && startIdx != null;

    return TimetableParseResult(
      isSuccess: confidenceSuccess,
      dayColIdx: dayIdx,
      subjectColIdx: subjectIdx,
      startTimeColIdx: startIdx,
      endTimeColIdx: endIdx,
      rows: rows,
    );
  }
}
