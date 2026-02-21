import 'package:flutter/material.dart';

/// Model representing a Quran reciter (Qari)
class Reciter {
  final String id;
  final String name;
  final String arabicName;
  final String? description;
  final String audioUrlPattern;
  final int bitrate;
  final String? country;

  const Reciter({
    required this.id,
    required this.name,
    required this.arabicName,
    this.description,
    required this.audioUrlPattern,
    this.bitrate = 128,
    this.country,
  });

  /// Get the audio URL for a specific surah and ayah number
  String getAudioUrl(int surahNumber, int ayahNumberInSurah) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumberInSurah.toString().padLeft(3, '0');
    return audioUrlPattern
        .replaceAll('{surah}', s)
        .replaceAll('{ayah}', a);
  }

  /// Get the display name based on language
  String getDisplayName(dynamic language) {
    // We use dynamic to avoid circular dependency with LanguageService
    // or we can just check for string representations if needed.
    // In this app, AppLanguage is an enum.
    final langStr = language.toString();
    if (langStr.contains('arabic')) {
      return arabicName;
    }
    return name;
  }
}

/// Famous Quran reciters using everyayah.com
class Reciters {
  static const Reciter alafasy = Reciter(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    arabicName: 'مشاري راشد العفاسي',
    audioUrlPattern: 'https://everyayah.com/data/Alafasy_128kbps/{surah}{ayah}.mp3',
  );

  static const Reciter sudais = Reciter(
    id: 'sudais',
    name: 'Abdul Rahman Al-Sudais',
    arabicName: 'عبد الرحمن السديس',
    audioUrlPattern: 'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps/{surah}{ayah}.mp3',
  );

  static const Reciter ghamdi = Reciter(
    id: 'ghamdi',
    name: 'Saad Al-Ghamdi',
    arabicName: 'سعد الغامدي',
    audioUrlPattern: 'https://everyayah.com/data/Ghamadi_40kbps/{surah}{ayah}.mp3',
  );

  static const Reciter muaiqly = Reciter(
    id: 'muaiqly',
    name: 'Maher Al-Muaiqly',
    arabicName: 'ماهر المعيقلي',
    audioUrlPattern: 'https://everyayah.com/data/Maher_AlMuaiqly_64kbps/{surah}{ayah}.mp3',
  );

  static const Reciter abdulbasit = Reciter(
    id: 'abdulbasit',
    name: 'Abdul Basit Abdus Samad',
    arabicName: 'عبد الباسط عبد الصمد',
    audioUrlPattern: 'https://everyayah.com/data/Abdul_Basit_Murattal_192kbps/{surah}{ayah}.mp3',
  );

  static const Reciter dosari = Reciter(
    id: 'dosari',
    name: 'Yasser Al-Dosari',
    arabicName: 'ياسر الدوسري',
    audioUrlPattern: 'https://everyayah.com/data/Yasser_Ad-Dussary_128kbps/{surah}{ayah}.mp3',
  );

  /// List of all available reciters
  static const List<Reciter> all = [
    alafasy,
    sudais,
    ghamdi,
    muaiqly,
    abdulbasit,
    dosari,
  ];

  static Reciter getById(String id) {
    return all.firstWhere((r) => r.id == id, orElse: () => alafasy);
  }

  static Reciter getDefault() => alafasy;
}
