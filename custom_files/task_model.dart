import 'package:hive/hive.dart';

class Task {
  String id;
  String title;
  String description;
  String subject;
  DateTime date;
  String? startTime;
  String? endTime;
  int priority; // 0: Low, 1: Medium, 2: High
  String repeat; // 'none', 'daily', 'weekly'
  int? reminderMinutesBefore; // null for no reminder
  bool completed;
  int xpReward;
  int coinReward;
  String notes;
  String colorHex;
  String category;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.date,
    this.startTime,
    this.endTime,
    required this.priority,
    required this.repeat,
    this.reminderMinutesBefore,
    this.completed = false,
    required this.xpReward,
    required this.coinReward,
    required this.notes,
    required this.colorHex,
    required this.category,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    DateTime? date,
    String? startTime,
    String? endTime,
    int? priority,
    String? repeat,
    int? reminderMinutesBefore,
    bool? completed,
    int? xpReward,
    int? coinReward,
    String? notes,
    String? colorHex,
    String? category,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      repeat: repeat ?? this.repeat,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      completed: completed ?? this.completed,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      notes: notes ?? this.notes,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
    );
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      subject: fields[3] as String,
      date: fields[4] as DateTime,
      startTime: fields[5] as String?,
      endTime: fields[6] as String?,
      priority: fields[7] as int,
      repeat: fields[8] as String,
      reminderMinutesBefore: fields[9] as int?,
      completed: fields[10] as bool,
      xpReward: fields[11] as int,
      coinReward: fields[12] as int,
      notes: fields[13] as String,
      colorHex: fields[14] as String,
      category: fields[15] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.subject)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.startTime)
      ..writeByte(6)
      ..write(obj.endTime)
      ..writeByte(7)
      ..write(obj.priority)
      ..writeByte(8)
      ..write(obj.repeat)
      ..writeByte(9)
      ..write(obj.reminderMinutesBefore)
      ..writeByte(10)
      ..write(obj.completed)
      ..writeByte(11)
      ..write(obj.xpReward)
      ..writeByte(12)
      ..write(obj.coinReward)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.colorHex)
      ..writeByte(15)
      ..write(obj.category);
  }
}
