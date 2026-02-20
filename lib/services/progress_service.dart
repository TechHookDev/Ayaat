import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _totalPointsKey = 'progress_total_points';
  static const String _totalAyahsKey = 'progress_total_ayahs';
  static const String _currentStreakKey = 'progress_current_streak';
  static const String _bestStreakKey = 'progress_best_streak';
  static const String _lastReadDateKey = 'progress_last_read_date';

  // Singleton pattern
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  bool _isProcessing = false;
  int _pendingPoints = 0;

  /// Gets the total points earned
  Future<int> getTotalPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalPointsKey) ?? 0;
  }



  /// Gets the total number of ayahs read all-time (legacy support)
  Future<int> getTotalAyahsRead() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalAyahsKey) ?? 0;
  }

  /// Gets the current consecutive reading streak (in days)
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentStreakKey) ?? 0;
  }

  /// Reward points and update streak for daily session
  Future<void> incrementStreakOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final lastReadDateString = prefs.getString(_lastReadDateKey);

    // Only award daily streak XP once per day
    if (lastReadDateString != todayString) {
      await addPoints(50); // Daily streak reward
    } else {
      // Just ensure streak is healthy if already read today
      await markAyahRead(count: 0);
    }
  }

  /// Adds points for an activity
  Future<void> addPoints(int points) async {
    if (points <= 0) return;
    
    _pendingPoints += points;
    debugPrint('addPoints called with: $points, pending total: $_pendingPoints');
    
    if (_isProcessing) return;
    _isProcessing = true;
    
    try {
      while (_pendingPoints > 0) {
        final toAdd = _pendingPoints;
        _pendingPoints -= toAdd;

        final prefs = await SharedPreferences.getInstance();
        final current = prefs.getInt(_totalPointsKey) ?? 0;
        await prefs.setInt(_totalPointsKey, current + toAdd);
        
        // Ensure streak logic is triggered
        final today = DateTime.now();
        final todayString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        final lastReadDateString = prefs.getString(_lastReadDateKey);

        if (lastReadDateString == null) {
          await prefs.setInt(_currentStreakKey, 1);
          await prefs.setInt(_bestStreakKey, 1);
          await prefs.setString(_lastReadDateKey, todayString);
        } else if (lastReadDateString != todayString) {
          final lastReadDate = DateTime.parse(lastReadDateString);
          final difference = DateTime(today.year, today.month, today.day).difference(
              DateTime(lastReadDate.year, lastReadDate.month, lastReadDate.day)).inDays;

          if (difference == 1) {
            final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
            final newStreak = currentStreak + 1;
            await prefs.setInt(_currentStreakKey, newStreak);
            
            final bestStreak = prefs.getInt(_bestStreakKey) ?? 0;
            if (newStreak > bestStreak) {
              await prefs.setInt(_bestStreakKey, newStreak);
            }
          } else if (difference > 1) {
            await prefs.setInt(_currentStreakKey, 1);
          }
          await prefs.setString(_lastReadDateKey, todayString);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Marks an ayah as read (legacy/fallback)
  Future<void> markAyahRead({int count = 1}) async {
    // Re-use addPoints logic but track ayahs if needed
    // For now we just use addPoints(count) to represent progress
    await addPoints(count);
  }

  /// Refreshes the streak if the user missed a day (can be called on app startup)
  Future<void> checkStreakStatus() async {
     final prefs = await SharedPreferences.getInstance();
     final lastReadDateString = prefs.getString(_lastReadDateKey);
     
     if (lastReadDateString != null) {
        final today = DateTime.now();
        final lastReadDate = DateTime.parse(lastReadDateString);
        final difference = DateTime(today.year, today.month, today.day).difference(
          DateTime(lastReadDate.year, lastReadDate.month, lastReadDate.day)).inDays;
          
        if (difference > 1) {
           // They broke the streak, reset it to 0 so the UI reflects they haven't read today
           await prefs.setInt(_currentStreakKey, 0);
        }
     }
  }
}
