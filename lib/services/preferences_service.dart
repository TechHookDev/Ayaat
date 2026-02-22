import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _bookmarkSurahKey = 'bookmark_surah';
  static const String _bookmarkVerseKey = 'bookmark_verse';
  static const String _bookmarksKey = 'bookmarks_list'; // Multiple bookmarks
  static const String _fontSizeKey = 'mushaf_font_size';
  static const String _lastReadSurahKey = 'last_read_surah';
  static const String _lastReadVerseKey = 'last_read_verse';
  static const String _lastReadTimeKey = 'last_read_time';

  // Singleton pattern
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  /// Legacy: Save a single bookmark (for backward compatibility)
  Future<void> saveBookmark(int surahNumber, int verseInSurah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bookmarkSurahKey, surahNumber);
    await prefs.setInt(_bookmarkVerseKey, verseInSurah);
  }

  /// Legacy: Remove the single bookmark
  Future<void> removeBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarkSurahKey);
    await prefs.remove(_bookmarkVerseKey);
  }

  /// Legacy: Get the single bookmark
  Future<Map<String, int>?> getBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final surah = prefs.getInt(_bookmarkSurahKey);
    final verse = prefs.getInt(_bookmarkVerseKey);

    if (surah != null && verse != null) {
      return {'surah': surah, 'verse': verse};
    }
    return null;
  }

  /// Get all bookmarks (returns list of bookmark objects)
  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getString(_bookmarksKey);

    if (bookmarksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(bookmarksJson);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        // If parsing fails, return empty list
        return [];
      }
    }

    // Migrate from legacy single bookmark if exists
    final legacy = await getBookmark();
    if (legacy != null) {
      final bookmark = {
        'surah': legacy['surah']!,
        'verse': legacy['verse']!,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await saveAllBookmarks([bookmark]);
      return [bookmark];
    }

    return [];
  }

  /// Save all bookmarks
  Future<void> saveAllBookmarks(List<Map<String, dynamic>> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookmarksKey, jsonEncode(bookmarks));
  }

  /// Add a new bookmark (if not already exists)
  Future<void> addBookmark(int surahNumber, int verseInSurah) async {
    final bookmarks = await getAllBookmarks();

    // Check if this bookmark already exists
    final exists = bookmarks.any(
      (b) => b['surah'] == surahNumber && b['verse'] == verseInSurah,
    );

    if (!exists) {
      bookmarks.add({
        'surah': surahNumber,
        'verse': verseInSurah,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await saveAllBookmarks(bookmarks);
    }
  }

  /// Remove a specific bookmark by surah and verse
  Future<void> removeBookmarkByPosition(
    int surahNumber,
    int verseInSurah,
  ) async {
    final bookmarks = await getAllBookmarks();
    bookmarks.removeWhere(
      (b) => b['surah'] == surahNumber && b['verse'] == verseInSurah,
    );
    await saveAllBookmarks(bookmarks);
  }

  /// Check if a specific verse is bookmarked
  Future<bool> isBookmarked(int surahNumber, int verseInSurah) async {
    final bookmarks = await getAllBookmarks();
    return bookmarks.any(
      (b) => b['surah'] == surahNumber && b['verse'] == verseInSurah,
    );
  }

  /// Save the last reading position (auto-saved as user reads)
  Future<void> saveLastReadPosition(int surahNumber, int verseInSurah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadSurahKey, surahNumber);
    await prefs.setInt(_lastReadVerseKey, verseInSurah);
    await prefs.setString(_lastReadTimeKey, DateTime.now().toIso8601String());
  }

  /// Get the last reading position
  Future<Map<String, dynamic>?> getLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final surah = prefs.getInt(_lastReadSurahKey);
    final verse = prefs.getInt(_lastReadVerseKey);
    final timeStr = prefs.getString(_lastReadTimeKey);

    if (surah != null && verse != null) {
      return {
        'surah': surah,
        'verse': verse,
        'timestamp': timeStr != null ? DateTime.parse(timeStr) : null,
      };
    }
    return null;
  }

  /// Clear the last reading position
  Future<void> clearLastReadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReadSurahKey);
    await prefs.remove(_lastReadVerseKey);
    await prefs.remove(_lastReadTimeKey);
  }

  Future<void> saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }

  Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 24.0; // Default arabic font size
  }
}
