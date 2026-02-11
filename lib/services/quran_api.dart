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

  /// Fetches a random verse from the Quran in the specified language
  Future<Verse> getRandomVerse({AppLanguage? language}) async {
    final randomAyahNumber = _random.nextInt(_totalVerses) + 1;
    return getVerse(randomAyahNumber, language: language);
  }

  /// Fetches a specific verse by its global number (1-6236) in the specified language
  Future<Verse> getVerse(int ayahNumber, {AppLanguage? language}) async {
    final langService = LanguageService();
    final selectedLanguage = language ?? await langService.getCurrentLanguage();
    final edition = langService.getApiEdition(selectedLanguage);

    final url = Uri.parse('$_baseUrl/ayah/$ayahNumber/$edition');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Verse.fromJson(json);
      } else {
        throw Exception('Failed to load verse: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching verse: $e');
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
}
