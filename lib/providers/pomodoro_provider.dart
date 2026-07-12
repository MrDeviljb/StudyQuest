import 'dart:async';
import 'package:flutter/material.dart';

class PomodoroProvider with ChangeNotifier {
  // Configs (in minutes)
  int _focusDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;

  int _remainingSeconds = 25 * 60;
  Timer? _timer;

  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreak = false;
  
  int _completedSessions = 0;
  String _currentSessionType = 'Focus Session'; // 'Focus Session', 'Short Break', 'Long Break'

  // Getters
  int get focusDuration => _focusDuration;
  int get shortBreakDuration => _shortBreakDuration;
  int get longBreakDuration => _longBreakDuration;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isBreak => _isBreak;
  int get completedSessions => _completedSessions;
  String get currentSessionType => _currentSessionType;

  // Formatted remaining time string MM:SS
  String get timerString {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progressPercentage {
    int total = _isBreak 
        ? (_currentSessionType == 'Long Break' ? _longBreakDuration : _shortBreakDuration) * 60
        : _focusDuration * 60;
    return (total - _remainingSeconds) / total;
  }

  void setConfig({int? focus, int? shortBreak, int? longBreak}) {
    if (focus != null) _focusDuration = focus;
    if (shortBreak != null) _shortBreakDuration = shortBreak;
    if (longBreak != null) _longBreakDuration = longBreak;
    resetTimer();
  }

  void startFocus() {
    _timer?.cancel();
    _isRunning = true;
    _isPaused = false;
    _isBreak = false;
    _currentSessionType = 'Focus Session';
    _remainingSeconds = _focusDuration * 60;
    
    _startTimerTicks();
    notifyListeners();
  }

  void pause() {
    if (_isRunning && !_isPaused) {
      _timer?.cancel();
      _isPaused = true;
      notifyListeners();
    }
  }

  void resume() {
    if (_isRunning && _isPaused) {
      _isPaused = false;
      _startTimerTicks();
      notifyListeners();
    }
  }

  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _isBreak = false;
    _currentSessionType = 'Focus Session';
    _remainingSeconds = _focusDuration * 60;
    notifyListeners();
  }

  void skip() {
    _timer?.cancel();
    _sessionCompleted(skipped: true);
  }

  void _startTimerTicks() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _sessionCompleted(skipped: false);
      }
    });
  }

  // Handle when session finishes
  void _sessionCompleted({required bool skipped}) {
    _isRunning = false;
    _isPaused = false;

    if (!_isBreak) {
      // Completed a Focus Session
      if (!skipped) {
        _completedSessions++;
      }
      // Determine break type: every 4th session is a long break
      if (_completedSessions > 0 && _completedSessions % 4 == 0) {
        _isBreak = true;
        _currentSessionType = 'Long Break';
        _remainingSeconds = _longBreakDuration * 60;
      } else {
        _isBreak = true;
        _currentSessionType = 'Short Break';
        _remainingSeconds = _shortBreakDuration * 60;
      }
    } else {
      // Completed a Break Session
      _isBreak = false;
      _currentSessionType = 'Focus Session';
      _remainingSeconds = _focusDuration * 60;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
