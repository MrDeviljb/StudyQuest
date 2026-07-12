import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyquest/services/timetable_parser.dart';

void main() {
  group('TimetableParser Multi-Layout Tests', () {
    test('1. Simple List Layout Auto-detection', () {
      final csvData = '''
Title Row 1 (Ignore)
Title Row 2 (Ignore)

Day,Time,Task
Monday,7:00–8:30 PM,Data Structures
Monday,9:00–10:00 PM,Revision

Daily Habit
Sleep,10:00 PM,8 Hours

Tuesday,6:30–7:30 PM,OOP
Tuesday,,
Tuesday,8:00–9:00 PM,Database

Summary
Completed tasks,3,100%
''';

      final bytes = utf8.encode(csvData);
      final result = TimetableParser.parseCsv(bytes);

      expect(result.isSuccess, isTrue);
      expect(result.layoutType, equals(TimetableLayoutType.list));
      expect(result.confidenceScore, equals(0.95));
      expect(result.dayIdx, equals(0));
      expect(result.timeIdx, equals(1));
      expect(result.subjectIdx, equals(2));

      expect(result.parsedTasks.length, equals(4));
      expect(result.parsedTasks[0].subject, equals('Data Structures'));
      expect(result.parsedTasks[0].day, equals('Monday'));
      expect(result.parsedTasks[0].startTime, equals('7:00 PM'));
      expect(result.parsedTasks[0].endTime, equals('8:30 PM'));

      expect(result.parsedTasks[2].subject, equals('OOP'));
      expect(result.parsedTasks[2].day, equals('Tuesday'));
      expect(result.parsedTasks[2].startTime, equals('6:30 PM'));
      expect(result.parsedTasks[2].endTime, equals('7:30 PM'));
    });

    test('2. Grid Layout Auto-detection (Days on Top, Time on Left)', () {
      final csvData = '''
Timetable Grid Mode
Time,Monday,Tuesday,Wednesday,Thursday,Friday
9:00–10:00 AM,Data Structures,OOP,,Career Skills,Python
10:00–11:00 AM,Data Structures,OOP,,Career Skills,Python
11:00 AM - 12:00 PM,DSA Lab,Theory,Practical,,
''';

      final bytes = utf8.encode(csvData);
      final result = TimetableParser.parseCsv(bytes);

      expect(result.isSuccess, isTrue);
      expect(result.layoutType, equals(TimetableLayoutType.gridDaysHeader));
      expect(result.dayIdx, equals(1)); // Day is row index 1
      expect(result.timeIdx, equals(0)); // Time is column index 0

      // Valid parsed tasks:
      // Monday 9:00-11:00 AM (merged) Data Structures
      // Monday 11:00 AM-12:00 PM DSA Lab
      // Tuesday 9:00-11:00 AM (merged) OOP
      // Tuesday 11:00 AM-12:00 PM Theory
      // Wednesday 11:00 AM-12:00 PM Practical
      // Thursday 9:00-11:00 AM (merged) Career Skills
      // Friday 9:00-11:00 AM (merged) Python
      
      final dsaTasks = result.parsedTasks.where((t) => t.subject == 'Data Structures').toList();
      expect(dsaTasks.length, equals(1));
      expect(dsaTasks[0].day, equals('Monday'));
      expect(dsaTasks[0].startTime, equals('9:00 AM'));
      expect(dsaTasks[0].endTime, equals('11:00 AM')); // Sequential merge checked!

      final oopTasks = result.parsedTasks.where((t) => t.subject == 'OOP').toList();
      expect(oopTasks.length, equals(1));
      expect(oopTasks[0].day, equals('Tuesday'));
      expect(oopTasks[0].startTime, equals('9:00 AM'));
      expect(oopTasks[0].endTime, equals('11:00 AM'));
    });

    test('3. Grid Layout Auto-detection (Time on Top, Days on Left)', () {
      final csvData = '''
Transposed Timetable
Day,9:00–10:00 AM,10:00–11:00 AM,11:00 AM - 12:00 PM
Monday,OOP,OOP,DSA Lab
Tuesday,Python,,Theory
''';

      final bytes = utf8.encode(csvData);
      final result = TimetableParser.parseCsv(bytes);

      expect(result.isSuccess, isTrue);
      expect(result.layoutType, equals(TimetableLayoutType.gridTimesHeader));
      expect(result.dayIdx, equals(0)); // Day is column index 0
      expect(result.timeIdx, equals(1)); // Time is row index 1

      final oopTasks = result.parsedTasks.where((t) => t.subject == 'OOP').toList();
      expect(oopTasks.length, equals(1));
      expect(oopTasks[0].day, equals('Monday'));
      expect(oopTasks[0].startTime, equals('9:00 AM'));
      expect(oopTasks[0].endTime, equals('11:00 AM'));

      final theoryTasks = result.parsedTasks.where((t) => t.subject == 'Theory').toList();
      expect(theoryTasks.length, equals(1));
      expect(theoryTasks[0].day, equals('Tuesday'));
      expect(theoryTasks[0].startTime, equals('11:00 AM'));
      expect(theoryTasks[0].endTime, equals('12:00 PM'));
    });

    test('4. Time String Normalizer Parsing Cases', () {
      expect(TimetableParser.parseTimeRange('7 PM'), equals({'start': '7:00 PM', 'end': ''}));
      expect(TimetableParser.parseTimeRange('19:00'), equals({'start': '7:00 PM', 'end': ''}));
      expect(TimetableParser.parseTimeRange('7:00-8:30 PM'), equals({'start': '7:00 PM', 'end': '8:30 PM'}));
      expect(TimetableParser.parseTimeRange('07:00-08:30'), equals({'start': '7:00 AM', 'end': '8:30 AM'}));
      expect(TimetableParser.parseTimeRange('8:00 AM - 9:50 AM'), equals({'start': '8:00 AM', 'end': '9:50 AM'}));
      expect(TimetableParser.parseTimeRange('11:00-1:00 PM'), equals({'start': '11:00 AM', 'end': '1:00 PM'}));
    });
  });
}
