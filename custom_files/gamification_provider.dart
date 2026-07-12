import 'package:flutter/material.dart';
import 'profile_model.dart';
import 'hive_service.dart';

class GamificationProvider with ChangeNotifier {
  late UserProfile _profile;
  bool _levelUpTriggered = false;
  String? _newlyUnlockedBadge;

  UserProfile get profile => _profile;
  bool get levelUpTriggered => _levelUpTriggered;
  String? get newlyUnlockedBadge => _newlyUnlockedBadge;

  GamificationProvider() {
    loadProfile();
  }

  void loadProfile() {
    _profile = HiveService.getUserProfile();
    // Daily reset check for stats if date changes
    _checkDailyReset();
    notifyListeners();
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    final lastAct = _profile.lastActivityDate;
    if (lastAct != null) {
      final isSameDay = now.year == lastAct.year &&
          now.month == lastAct.month &&
          now.day == lastAct.day;
      if (!isSameDay) {
        // It's a new day! Reset daily study time
        _profile.todayStudyTimeMinutes = 0;
        
        // Reset streak if missed yesterday (more than 1 day difference)
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastAct.year, lastAct.month, lastAct.day))
            .inDays;
        
        if (diff > 1) {
          _profile.currentStreak = 0; // Streak broken
        }
        
        HiveService.saveUserProfile(_profile);
      }
    }
  }

  void clearLevelUpTrigger() {
    _levelUpTriggered = false;
    notifyListeners();
  }

  void clearBadgeTrigger() {
    _newlyUnlockedBadge = null;
    notifyListeners();
  }

  // Award XP and Coins on completing tasks
  Future<void> awardRewards(int xpAmount, int coinsAmount) async {
    _checkDailyReset();

    // 1. Update XP and Level
    int newXP = _profile.xp + xpAmount;
    int currentLevel = _profile.level;
    
    // Check level up (e.g. 100 XP per level)
    int xpNeeded = currentLevel * 100;
    if (newXP >= xpNeeded && xpAmount > 0) {
      newXP -= xpNeeded;
      currentLevel++;
      _levelUpTriggered = true;
    } else if (newXP < 0) {
      // If task is uncompleted, make sure XP doesn't drop below 0 at Level 1
      if (currentLevel > 1 && newXP < 0) {
        currentLevel--;
        newXP += currentLevel * 100;
      } else {
        newXP = 0;
      }
    }

    _profile.xp = newXP;
    _profile.level = currentLevel;

    // 2. Update Coins
    _profile.coins = (_profile.coins + coinsAmount).clamp(0, 999999);

    // 3. Update Completed Tasks Count
    if (xpAmount > 0) {
      _profile.totalCompletedTasks++;
      _updateStreak();
    } else {
      _profile.totalCompletedTasks = (_profile.totalCompletedTasks - 1).clamp(0, 999999);
    }

    // 4. Check achievements
    _checkBadges();

    await HiveService.saveUserProfile(_profile);
    notifyListeners();
  }

  // Handle daily login reward
  bool get canClaimDailyReward {
    final now = DateTime.now();
    final lastClaimedStr = HiveService.settingsBox.get('last_claimed_daily_reward') as String?;
    if (lastClaimedStr == null) return true;

    final lastClaimed = DateTime.parse(lastClaimedStr);
    return !(now.year == lastClaimed.year &&
        now.month == lastClaimed.month &&
        now.day == lastClaimed.day);
  }

  Future<void> claimDailyReward() async {
    if (!canClaimDailyReward) return;

    final now = DateTime.now();
    await HiveService.settingsBox.put('last_claimed_daily_reward', now.toIso8601String());

    // Daily reward: 50 XP and 30 Coins
    await awardRewards(50, 30);
  }

  void _updateStreak() {
    final now = DateTime.now();
    final lastAct = _profile.lastActivityDate;

    if (lastAct == null) {
      _profile.currentStreak = 1;
      _profile.longestStreak = 1;
    } else {
      final isSameDay = now.year == lastAct.year &&
          now.month == lastAct.month &&
          now.day == lastAct.day;
      
      final isYesterday = now.year == lastAct.year &&
          now.month == lastAct.month &&
          now.day == lastAct.day - 1; // simple check, but let's do diff:
      
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastAct.year, lastAct.month, lastAct.day))
          .inDays;

      if (!isSameDay) {
        if (diff == 1) {
          // Increment streak
          _profile.currentStreak++;
          if (_profile.currentStreak > _profile.longestStreak) {
            _profile.longestStreak = _profile.currentStreak;
          }
        } else {
          // Reset streak to 1
          _profile.currentStreak = 1;
        }
      }
    }
    
    _profile.lastActivityDate = now;
  }

  // Log study time from Pomodoro
  Future<void> addStudyTime(int minutes) async {
    _checkDailyReset();

    _profile.todayStudyTimeMinutes += minutes;
    _profile.weeklyStudyTimeMinutes += minutes;
    _profile.monthlyStudyTimeMinutes += minutes;
    
    double addedHours = minutes / 60.0;
    _profile.totalFocusHours += addedHours;

    // Check hours-based achievements
    _checkBadges();

    await HiveService.saveUserProfile(_profile);
    notifyListeners();
  }

  // Check achievements requirements
  void _checkBadges() {
    final badges = _profile.unlockedBadges;

    void unlock(String badgeId) {
      if (!badges.contains(badgeId)) {
        badges.add(badgeId);
        _newlyUnlockedBadge = badgeId;
      }
    }

    // Badge 1: First Task
    if (_profile.totalCompletedTasks >= 1) {
      unlock('first_task');
    }

    // Badge 2: 7 Day Streak
    if (_profile.currentStreak >= 7) {
      unlock('streak_7');
    }

    // Badge 3: 30 Day Streak
    if (_profile.currentStreak >= 30) {
      unlock('streak_30');
    }

    // Badge 4: 100 Tasks Completed
    if (_profile.totalCompletedTasks >= 100) {
      unlock('tasks_100');
    }

    // Badge 5: 100 Hours Focused
    if (_profile.totalFocusHours >= 100.0) {
      unlock('hours_100');
    }
  }

  // Get description for badges
  static Map<String, String> getBadgeDetails(String badgeId) {
    switch (badgeId) {
      case 'first_task':
        return {
          'title': 'Initiation',
          'description': 'Completed your very first study task!',
          'icon': '🏆'
        };
      case 'streak_7':
        return {
          'title': 'Week on Fire',
          'description': 'Maintained a 7-day study streak!',
          'icon': '🔥'
        };
      case 'streak_30':
        return {
          'title': 'Habit Master',
          'description': 'Maintained a 30-day study streak!',
          'icon': '👑'
        };
      case 'tasks_100':
        return {
          'title': 'Century Conqueror',
          'description': 'Completed 100 tasks in total!',
          'icon': '💯'
        };
      case 'hours_100':
        return {
          'title': 'Deep Work Legend',
          'description': 'Spent 100 hours focusing in Pomodoro!',
          'icon': '🧠'
        };
      default:
        return {
          'title': 'Achievement Unlocked',
          'description': 'You unlocked a new badge!',
          'icon': '⭐'
        };
    }
  }

  static List<String> getAllPossibleBadges() {
    return ['first_task', 'streak_7', 'streak_30', 'tasks_100', 'hours_100'];
  }
}
