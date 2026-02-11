import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages for the app
enum AppLanguage {
  arabic('ar', 'العربية'),
  english('en', 'English'),
  french('fr', 'Français');

  final String code;
  final String name;

  const AppLanguage(this.code, this.name);
}

/// Service for managing app language preferences
class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _languageKey = 'app_language';

  /// Get the currently selected language (default: Arabic)
  Future<AppLanguage> getCurrentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'ar';

    switch (languageCode) {
      case 'en':
        return AppLanguage.english;
      case 'fr':
        return AppLanguage.french;
      case 'ar':
      default:
        return AppLanguage.arabic;
    }
  }

  /// Set the app language
  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
  }

  /// Get language code string
  String getLanguageCode(AppLanguage language) {
    return language.code;
  }

  /// Get API edition code for Quran API based on language
  String getApiEdition(AppLanguage language) {
    switch (language) {
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.english:
        return 'en.sahih';
      case AppLanguage.french:
        return 'fr.hamidullah';
    }
  }
}
