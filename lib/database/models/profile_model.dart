import 'package:hive/hive.dart';

class UserProfile {
  String name;
  int xp;
  int coins;
  int level;
  int currentStreak;
  int longestStreak;
  DateTime? lastActivityDate;
  List<String> unlockedBadges;
  
  // Tracking Stats
  int todayStudyTimeMinutes; // in minutes
  int weeklyStudyTimeMinutes;
  int monthlyStudyTimeMinutes;
  int totalCompletedTasks;
  double totalFocusHours;

  UserProfile({
    required this.name,
    this.xp = 0,
    this.coins = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    required this.unlockedBadges,
    this.todayStudyTimeMinutes = 0,
    this.weeklyStudyTimeMinutes = 0,
    this.monthlyStudyTimeMinutes = 0,
    this.totalCompletedTasks = 0,
    this.totalFocusHours = 0.0,
  });

  UserProfile copyWith({
    String? name,
    int? xp,
    int? coins,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
    List<String>? unlockedBadges,
    int? todayStudyTimeMinutes,
    int? weeklyStudyTimeMinutes,
    int? monthlyStudyTimeMinutes,
    int? totalCompletedTasks,
    double? totalFocusHours,
  }) {
    return UserProfile(
      name: name ?? this.name,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      todayStudyTimeMinutes: todayStudyTimeMinutes ?? this.todayStudyTimeMinutes,
      weeklyStudyTimeMinutes: weeklyStudyTimeMinutes ?? this.weeklyStudyTimeMinutes,
      monthlyStudyTimeMinutes: monthlyStudyTimeMinutes ?? this.monthlyStudyTimeMinutes,
      totalCompletedTasks: totalCompletedTasks ?? this.totalCompletedTasks,
      totalFocusHours: totalFocusHours ?? this.totalFocusHours,
    );
  }
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 1;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      xp: fields[1] as int,
      coins: fields[2] as int,
      level: fields[3] as int,
      currentStreak: fields[4] as int,
      longestStreak: fields[5] as int,
      lastActivityDate: fields[6] as DateTime?,
      unlockedBadges: (fields[7] as List).cast<String>(),
      todayStudyTimeMinutes: fields[8] as int? ?? 0,
      weeklyStudyTimeMinutes: fields[9] as int? ?? 0,
      monthlyStudyTimeMinutes: fields[10] as int? ?? 0,
      totalCompletedTasks: fields[11] as int? ?? 0,
      totalFocusHours: fields[12] as double? ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.xp)
      ..writeByte(2)
      ..write(obj.coins)
      ..writeByte(3)
      ..write(obj.level)
      ..writeByte(4)
      ..write(obj.currentStreak)
      ..writeByte(5)
      ..write(obj.longestStreak)
      ..writeByte(6)
      ..write(obj.lastActivityDate)
      ..writeByte(7)
      ..write(obj.unlockedBadges)
      ..writeByte(8)
      ..write(obj.todayStudyTimeMinutes)
      ..writeByte(9)
      ..write(obj.weeklyStudyTimeMinutes)
      ..writeByte(10)
      ..write(obj.monthlyStudyTimeMinutes)
      ..writeByte(11)
      ..write(obj.totalCompletedTasks)
      ..writeByte(12)
      ..write(obj.totalFocusHours);
  }
}
