import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/verse.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/quran_api.dart';
import 'settings_screen.dart';
import 'verse_detail_screen.dart';
import 'surah_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final int? initialVerseNumber;
  const HomeScreen({super.key, this.initialVerseNumber});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final QuranApiService _quranApi = QuranApiService();
  final LanguageService _languageService = LanguageService();
  final NotificationService _notificationService = NotificationService();
  AppLanguage _currentLanguage = AppLanguage.arabic;
  Map<String, Verse>? _currentVerses;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadVerses();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVerseNumber != oldWidget.initialVerseNumber &&
        widget.initialVerseNumber != null) {
      _loadVerses();
    }
  }

  Future<void> _loadLanguage() async {
    final language = await _languageService.getCurrentLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  Future<void> _loadVerses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Priority 1: Check validation from constructor (passed from notification tap)
      if (widget.initialVerseNumber != null) {
        final verses = await _quranApi.getVerseInAllLanguages(
          widget.initialVerseNumber!,
        );
        setState(() {
          _currentVerses = verses;
          _isLoading = false;
        });
        return;
      }

      // Priority 2: Check stored notification verse (legacy/fallback)
      final notificationVerse = await _notificationService
          .getNotificationVerse();
      if (notificationVerse != null) {
        // Fetch the verse in all 3 languages using the verse number
        final verses = await _quranApi.getVerseInAllLanguages(
          notificationVerse.number,
        );
        setState(() {
          _currentVerses = verses;
          _isLoading = false;
        });
      } else {
        await _loadRandomVerses();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRandomVerses() async {
    final verses = await _quranApi.getRandomVerseInAllLanguages();
    setState(() {
      _currentVerses = verses;
      _isLoading = false;
    });
  }

  String _getNewVerseText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'آية جديدة';
      case AppLanguage.english:
        return 'New Verse';
      case AppLanguage.french:
        return 'Nouveau Verset';
    }
  }

  String _getTestNotificationText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'اختبار التنبيه';
      case AppLanguage.english:
        return 'Test Notification';
      case AppLanguage.french:
        return 'Tester Notification';
    }
  }

  String _getContinueReadingText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'متابعة القراءة';
      case AppLanguage.english:
        return 'Continue Reading';
      case AppLanguage.french:
        return 'Continuer la Lecture';
    }
  }

  String _getNotificationSentText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'تم إرسال تنبيه تجريبي';
      case AppLanguage.english:
        return 'Test notification sent';
      case AppLanguage.french:
        return 'Notification de test envoyée';
    }
  }

  String _getAppTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'آيات';
      case AppLanguage.english:
        return 'Ayaat';
      case AppLanguage.french:
        return 'Ayaat';
    }
  }

  String _getErrorText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'حدث خطأ في تحميل الآية';
      case AppLanguage.english:
        return 'Error loading verse';
      case AppLanguage.french:
        return 'Erreur lors du chargement du verset';
    }
  }

  String _getRetryText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'إعادة المحاولة';
      case AppLanguage.english:
        return 'Retry';
      case AppLanguage.french:
        return 'Réessayer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildVerseCard()),
              _buildActions(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Quran Button - LEFT
          Positioned(
            left: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SurahListScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xFFFFD700), size: 24),
                      const SizedBox(height: 2),
                      Text(
                        _currentLanguage == AppLanguage.arabic ? 'المصحف' : 'Mushaf',
                        style: GoogleFonts.amiri(
                          fontSize: 10,
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Centered App Title
          Center(
            child: Text(
              _getAppTitle(),
              style: GoogleFonts.amiri(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          // Settings Button - aligned to right
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
                // Reload data when returning from settings
                await _loadLanguage();
                await _loadVerses();
              },
              icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                _getErrorText(),
                style: GoogleFonts.amiri(fontSize: 18, color: Colors.white70),
                textDirection: _currentLanguage == AppLanguage.arabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadVerses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                child: Text(_getRetryText()),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '﷽',
                    style: GoogleFonts.amiri(
                      fontSize: 24,
                      color: const Color(0xFFFFD700),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...() {
                    final sections = [
                      MapEntry(
                        AppLanguage.arabic,
                        _buildLanguageSection(
                          language: 'العربية',
                          verse: _currentVerses?['arabic'],
                          textDirection: TextDirection.rtl,
                          fontFamily: 'Amiri',
                          fontSize: 24,
                          reference: _currentVerses?['arabic']?.arabicReference ?? '',
                        ),
                      ),
                      MapEntry(
                        AppLanguage.english,
                        _buildLanguageSection(
                          language: 'English',
                          verse: _currentVerses?['english'],
                          textDirection: TextDirection.ltr,
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          reference: _currentVerses?['english']?.englishReference ?? '',
                        ),
                      ),
                      MapEntry(
                        AppLanguage.french,
                        _buildLanguageSection(
                          language: 'Français',
                          verse: _currentVerses?['french'],
                          textDirection: TextDirection.ltr,
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          reference: _currentVerses?['french']?.frenchReference ?? '',
                        ),
                      ),
                    ];

                    // Sort: Selected language first, then others
                    sections.sort((a, b) {
                      if (a.key == _currentLanguage) return -1;
                      if (b.key == _currentLanguage) return 1;
                      return 0;
                    });

                    final List<Widget> widgets = [];
                    for (int i = 0; i < sections.length; i++) {
                      widgets.add(sections[i].value);
                      if (i < sections.length - 1) {
                        widgets.add(const Divider(color: Colors.white24, height: 32));
                      }
                    }
                    return widgets;
                  }(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _removeBismillah(String text, int surahNumber, int numberInSurah) {
    // Only remove bismillah from first verse of surahs (except Surah 1 and 9)
    if (numberInSurah != 1 || surahNumber == 1 || surahNumber == 9) {
      return text;
    }

    // Remove BOM character if present
    text = text.replaceAll('\ufeff', '');

    // Check if verse contains bismillah
    if (text.contains('بسم') || text.contains('بِسْمِ')) {
      // Find end of bismillah (الرحيم)
      const targetSkeleton = "بسماللهالرحمنالرحيم";
      int targetIdx = 0;
      int textIdx = 0;

      while (textIdx < text.length && targetIdx < targetSkeleton.length) {
        if (text[textIdx] == targetSkeleton[targetIdx]) {
          targetIdx++;
        }
        textIdx++;
      }

      if (targetIdx >= targetSkeleton.length) {
        // Found complete bismillah, return text after it
        return text.substring(textIdx).trim();
      }
    }

    return text;
  }

  Widget _buildLanguageSection({
    required String language,
    required Verse? verse,
    required TextDirection textDirection,
    required String fontFamily,
    required double fontSize,
    required String reference,
  }) {
    // Remove bismillah from first verse (except Surah 1 and 9)
    String verseText = verse?.text ?? '';
    if (verse != null && language == 'العربية') {
      verseText = _removeBismillah(
        verseText,
        verse.surahNumber,
        verse.numberInSurah,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            language,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          verseText,
          style: fontFamily == 'Amiri'
              ? GoogleFonts.amiri(
                  fontSize: fontSize,
                  color: Colors.white,
                  height: 1.8,
                )
              : GoogleFonts.outfit(
                  fontSize: fontSize,
                  color: Colors.white,
                  height: 1.6,
                ),
          textAlign: TextAlign.center,
          textDirection: textDirection,
        ),
        const SizedBox(height: 8),
        Text(
          reference,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: Icons.menu_book,
            label: _getContinueReadingText(),
            onPressed: () {
              if (_currentVerses != null && _currentVerses!['arabic'] != null) {
                final arabicVerse = _currentVerses!['arabic']!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VerseDetailScreen(
                      surahNumber: arabicVerse.surahNumber,
                      numberInSurah: arabicVerse.numberInSurah,
                      language: _currentLanguage,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            icon: Icons.refresh,
            label: _getNewVerseText(),
            onPressed: () async {
              await _notificationService.clearNotificationVerse();
              _loadRandomVerses();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
