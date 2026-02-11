/// Model for storing notification verse data
class NotificationVerse {
  final int number;
  final String text;
  final String surahName;
  final String surahEnglishName;
  final int surahNumber;
  final int numberInSurah;
  final String language;

  NotificationVerse({
    required this.number,
    required this.text,
    required this.surahName,
    required this.surahEnglishName,
    required this.surahNumber,
    required this.numberInSurah,
    required this.language,
  });

  factory NotificationVerse.fromJson(Map<String, dynamic> json) {
    return NotificationVerse(
      number: json['number'] ?? 0,
      text: json['text'] ?? '',
      surahName: json['surahName'] ?? '',
      surahEnglishName: json['surahEnglishName'] ?? '',
      surahNumber: json['surahNumber'] ?? 0,
      numberInSurah: json['numberInSurah'] ?? 0,
      language: json['language'] ?? 'ar',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'text': text,
      'surahName': surahName,
      'surahEnglishName': surahEnglishName,
      'surahNumber': surahNumber,
      'numberInSurah': numberInSurah,
      'language': language,
    };
  }
}
