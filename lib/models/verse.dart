/// Model representing a Quran verse (Ayah)
class Verse {
  final int number;
  final String text;
  final String surahName;
  final String surahEnglishName;
  final String? surahFrenchName;
  final int surahNumber;
  final int numberInSurah;

  Verse({
    required this.number,
    required this.text,
    required this.surahName,
    required this.surahEnglishName,
    this.surahFrenchName,
    required this.surahNumber,
    required this.numberInSurah,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final surah = data['surah'] ?? {};

    return Verse(
      number: data['number'] ?? 0,
      text: data['text'] ?? '',
      surahName: surah['name'] ?? '',
      surahEnglishName: surah['englishName'] ?? '',
      surahFrenchName: surah['frenchName'],
      surahNumber: surah['number'] ?? 0,
      numberInSurah: data['numberInSurah'] ?? 0,
    );
  }

  /// Returns Arabic reference
  String get arabicReference => '$surahName - $numberInSurah آية';

  /// Returns English reference
  String get englishReference => '$surahEnglishName - Verse $numberInSurah';

  /// Returns French reference
  String get frenchReference =>
      '${surahFrenchName ?? surahEnglishName} - Verset $numberInSurah';

  /// Returns formatted reference (Arabic default)
  String get reference => arabicReference;
}
