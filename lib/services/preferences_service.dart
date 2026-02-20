import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _bookmarkSurahKey = 'bookmark_surah';
  static const String _bookmarkVerseKey = 'bookmark_verse';
  static const String _fontSizeKey = 'mushaf_font_size';

  // Singleton pattern
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  Future<void> saveBookmark(int surahNumber, int verseInSurah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bookmarkSurahKey, surahNumber);
    await prefs.setInt(_bookmarkVerseKey, verseInSurah);
  }

  Future<void> removeBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarkSurahKey);
    await prefs.remove(_bookmarkVerseKey);
  }

  Future<Map<String, int>?> getBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final surah = prefs.getInt(_bookmarkSurahKey);
    final verse = prefs.getInt(_bookmarkVerseKey);

    if (surah != null && verse != null) {
      return {'surah': surah, 'verse': verse};
    }
    return null;
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
