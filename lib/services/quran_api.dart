import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/verse.dart';
import 'language_service.dart';

/// Service for fetching Quran verses from alquran.cloud API
class QuranApiService {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';
  static const int _totalVerses = 6236;

  final Random _random = Random();
  
  // Helper to convert numbers to Arabic numerals
  static String toArabicNumerals(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }
  
  // In-memory cache for Surah data to achieve "Infinite Speed"
  static final Map<String, Map<String, List<dynamic>>> _surahCache = {};
  static final Map<AppLanguage, List<dynamic>> _surahListCache = {};

  static Map<String, Map<String, List<dynamic>>> getSurahCache() => _surahCache;

  /// Fetches a random verse from the Quran in the specified language
  Future<Verse> getRandomVerse({AppLanguage? language}) async {
    final randomAyahNumber = _random.nextInt(_totalVerses) + 1;
    return getVerse(randomAyahNumber, language: language);
  }

  /// Fetches all verses for a random Surah in a single API call
  Future<List<Verse>> getRandomSurahVerses({AppLanguage? language}) async {
    final langService = LanguageService();
    final selectedLanguage = language ?? await langService.getCurrentLanguage();
    final edition = langService.getApiEdition(selectedLanguage);
    
    // Choose a random Surah (1 to 114)
    final randomSurahNumber = _random.nextInt(114) + 1;

    final url = Uri.parse('$_baseUrl/surah/$randomSurahNumber/$edition');

    return _fetchWithRetry(() async {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final surahData = json['data'];
        final ayahsList = surahData['ayahs'] as List;
        
        final surahMeta = {
          'number': surahData['number'],
          'name': surahData['name'],
          'englishName': surahData['englishName'],
          'englishNameTranslation': surahData['englishNameTranslation'],
          'revelationType': surahData['revelationType'],
          'numberOfAyahs': surahData['numberOfAyahs'],
        };
        
        return ayahsList.map((ayah) {
          return Verse.fromJson({
            'number': ayah['number'],
            'text': ayah['text'],
            'numberInSurah': ayah['numberInSurah'],
            'surah': surahMeta,
          });
        }).toList();
      } else {
        throw Exception('Failed to load surah verses: \${response.statusCode}');
      }
    });
  }

  /// Fetches a specific verse by its global number (1-6236) in the specified language
  Future<Verse> getVerse(int ayahNumber, {AppLanguage? language}) async {
    final langService = LanguageService();
    final selectedLanguage = language ?? await langService.getCurrentLanguage();
    final edition = langService.getApiEdition(selectedLanguage);

    final url = Uri.parse('$_baseUrl/ayah/$ayahNumber/$edition');

    return _fetchWithRetry(() async {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Verse.fromJson(json);
      } else {
        throw Exception('Failed to load verse: ${response.statusCode}');
      }
    });
  }

  /// Helper to retry async operations with exponential backoff
  Future<T> _fetchWithRetry<T>(Future<T> Function() operation, {int retries = 3}) async {
    int attempt = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        if (e.toString().contains('429') || attempt >= retries) {
          if (attempt >= retries) rethrow;
          // If 429, wait longer
          final delay = Duration(seconds: (pow(2, attempt).toInt() * 2)); 
          print('Rate limit hit. Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          // Other errors, standard backoff
          await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
        }
        attempt++;
      }
    }
  }

  /// Fetches a random verse in all three languages
  Future<Map<String, Verse>> getRandomVerseInAllLanguages() async {
    final randomAyahNumber = _random.nextInt(_totalVerses) + 1;

    final urls = [
      Uri.parse('$_baseUrl/ayah/$randomAyahNumber/ar'),
      Uri.parse('$_baseUrl/ayah/$randomAyahNumber/en.sahih'),
      Uri.parse('$_baseUrl/ayah/$randomAyahNumber/fr.hamidullah'),
    ];

    try {
      final responses = await Future.wait([
        http.get(urls[0]),
        http.get(urls[1]),
        http.get(urls[2]),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        return {
          'arabic': Verse.fromJson(jsonDecode(responses[0].body)),
          'english': Verse.fromJson(jsonDecode(responses[1].body)),
          'french': Verse.fromJson(jsonDecode(responses[2].body)),
        };
      } else {
        throw Exception('Failed to load verses');
      }
    } catch (e) {
      throw Exception('Error fetching verses: $e');
    }
  }

  /// Fetches a specific verse by number in all three languages
  Future<Map<String, Verse>> getVerseInAllLanguages(int ayahNumber) async {
    final urls = [
      Uri.parse('$_baseUrl/ayah/$ayahNumber/ar'),
      Uri.parse('$_baseUrl/ayah/$ayahNumber/en.sahih'),
      Uri.parse('$_baseUrl/ayah/$ayahNumber/fr.hamidullah'),
    ];

    try {
      final responses = await Future.wait([
        http.get(urls[0]),
        http.get(urls[1]),
        http.get(urls[2]),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        return {
          'arabic': Verse.fromJson(jsonDecode(responses[0].body)),
          'english': Verse.fromJson(jsonDecode(responses[1].body)),
          'french': Verse.fromJson(jsonDecode(responses[2].body)),
        };
      } else {
        throw Exception('Failed to load verses');
      }
    } catch (e) {
      throw Exception('Error fetching verses: $e');
    }
  }

  /// Fetches a verse with English translation
  Future<Map<String, Verse>> getVerseWithTranslation(int ayahNumber) async {
    final arabicUrl = Uri.parse('$_baseUrl/ayah/$ayahNumber/ar');
    final englishUrl = Uri.parse('$_baseUrl/ayah/$ayahNumber/en.sahih');

    try {
      final responses = await Future.wait([
        http.get(arabicUrl),
        http.get(englishUrl),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        return {
          'arabic': Verse.fromJson(jsonDecode(responses[0].body)),
          'english': Verse.fromJson(jsonDecode(responses[1].body)),
        };
      } else {
        throw Exception('Failed to load verse with translation');
      }
    } catch (e) {
      throw Exception('Error fetching verse: $e');
    }
  }

  /// Fetches a full Surah with translation
  Future<Map<String, List<dynamic>>> getSurahWithTranslation(
      int surahNumber, AppLanguage language) async {
    final cacheKey = '$surahNumber-${language.name}';
    if (_surahCache.containsKey(cacheKey)) {
      return _surahCache[cacheKey]!;
    }

    final langService = LanguageService();
    AppLanguage translationLang = language == AppLanguage.arabic 
        ? AppLanguage.english 
        : language;

    final translationEdition = langService.getApiEdition(translationLang);
    final arabicEdition = 'ar'; 

    final arabicUrl = Uri.parse('$_baseUrl/surah/$surahNumber/$arabicEdition');
    final translationUrl = Uri.parse('$_baseUrl/surah/$surahNumber/$translationEdition');

    try {
      final responses = await Future.wait([
        http.get(arabicUrl),
        http.get(translationUrl),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final arabicData = jsonDecode(responses[0].body)['data'];
        final translationData = jsonDecode(responses[1].body)['data'];

        final result = {
          'arabic': arabicData['ayahs'] as List<dynamic>,
          'translation': translationData['ayahs'] as List<dynamic>,
        };
        
        _surahCache[cacheKey] = result;
        return result;
      } else {
        throw Exception('Failed to load surah with translation');
      }
    } catch (e) {
      throw Exception('Error fetching surah: $e');
    }
  }

  /// Returns the audio streaming URL for a specific global verse number
  String getAudioUrl(int globalAyahNumber) {
    // We use Mishary Alafasy's recitation
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$globalAyahNumber.mp3';
  }

  /// Fetches list of all Surahs
  Future<List<dynamic>> getSurahs(AppLanguage language) async {
    if (_surahListCache.containsKey(language)) {
      return _surahListCache[language]!;
    }
    
    try {
      final response = await http.get(Uri.parse('$_baseUrl/surah'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data'] as List<dynamic>;
        _surahListCache[language] = list;
        return list;
      } else {
        throw Exception('Failed to load surahs');
      }
    } catch (e) {
      throw Exception('Error fetching surahs: $e');
    }
  }
}
