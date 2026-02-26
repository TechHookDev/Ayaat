import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/verse.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/quran_api.dart';
import '../services/audio_service.dart';
import '../widgets/mini_player.dart';
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
  final AudioService _audioService = AudioService();
  AppLanguage _currentLanguage = AppLanguage.arabic;
  Map<String, Verse>? _currentVerses;
  bool _isLoading = true;
  String? _error;


  @override
  void initState() {
    super.initState();
    _audioService.initialize();
    _audioService.addListener(_onAudioStateChanged);
    _loadLanguage();
    _loadVerses();
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioStateChanged);
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {});
    }
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

      // No notification verse, load random verse
      await _loadRandomVerses();
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
        return 'آية أخرى';
      case AppLanguage.english:
        return 'Another Verse';
      case AppLanguage.french:
        return 'Un autre verset';
    }
  }

  String _getContinueReadingText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'أكمل وردك';
      case AppLanguage.english:
        return 'Continue Reading';
      case AppLanguage.french:
        return 'Continuer la lecture';
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
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.landscape) {
                return _buildLandscapeLayout();
              }
              return _buildPortraitLayout();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildVerseCard()),
        _buildActions(),
        // Mini Player - shows when audio is playing
        MiniPlayer(audioService: _audioService, language: _currentLanguage),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Header and Stats
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(isLandscape: true),
              ],
            ),
          ),
        ),
        // Right Column: Verse Card and Actions
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 20),
                  child: _buildVerseCard(),
                ),
              ),
              _buildActions(isLandscape: true),
              // Mini Player - shows when audio is playing
              MiniPlayer(
                audioService: _audioService,
                language: _currentLanguage,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 10 : 20,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Quran Button - LEFT
          Positioned(
            left: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
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
                      Icon(
                        Icons.menu_book,
                        color: const Color(0xFFFFD700),
                        size: isLandscape ? 20 : 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentLanguage == AppLanguage.arabic
                            ? 'المصحف'
                            : 'Mushaf',
                        style: GoogleFonts.amiri(
                          fontSize: isLandscape ? 8 : 10,
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
                fontSize: isLandscape ? 32 : 42,
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
                // Reload language when returning from settings
                await _loadLanguage();

                // Reload progress as they might have read something in Mushaf Pro

                // Only fetch a new verse if we didn't have one (e.g., previous network error)
                if (_currentVerses == null || _error != null) {
                  await _loadVerses();
                }
              },
              icon: Icon(
                Icons.settings,
                color: Colors.white70,
                size: isLandscape ? 24 : 28,
              ),
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
                  if (_currentVerses?['arabic']?.surahNumber != 9)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        '﷽',
                        style: GoogleFonts.amiri(
                          fontSize: 24,
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                    ),
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
                          reference:
                              _currentVerses?['arabic']?.arabicReference ?? '',
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
                          reference:
                              _currentVerses?['english']?.englishReference ??
                              '',
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
                          reference:
                              _currentVerses?['french']?.frenchReference ?? '',
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
                        widgets.add(
                          const Divider(color: Colors.white24, height: 32),
                        );
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
    // Only remove bismillah from first verse of surahs (except Surah 9)
    if (numberInSurah != 1 || surahNumber == 9) {
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

  String _getPlayAudioText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'استماع للآية';
      case AppLanguage.english:
        return 'Listen to Verse';
      case AppLanguage.french:
        return 'Écouter le Verset';
    }
  }

  String _getStopAudioText() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'إيقاف التلاوة';
      case AppLanguage.english:
        return 'Stop Recitation';
      case AppLanguage.french:
        return 'Arrêter la Récitation';
    }
  }

  Future<void> _playCurrentVerse() async {
    if (_currentVerses == null || _currentVerses!['arabic'] == null) return;

    final arabicVerse = _currentVerses!['arabic']!;

    // Check if this verse is already playing
    if (_audioService.currentSurahNumber == arabicVerse.surahNumber &&
        _audioService.currentAyahIndex == arabicVerse.numberInSurah - 1 &&
        _audioService.isPlaying) {
      await _audioService.pause();
    } else if (_audioService.currentSurahNumber == arabicVerse.surahNumber &&
        _audioService.currentAyahIndex == arabicVerse.numberInSurah - 1 &&
        !_audioService.isPlaying) {
      await _audioService.play();
    } else {
      // Play the verse

      // Navigate to verse detail screen to play the audio there
      await Navigator.push(
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
  }

  Widget _buildActions({bool isLandscape = false}) {
    final isAudioPlaying =
        _audioService.isPlaying &&
        _audioService.currentSurahNumber ==
            _currentVerses?['arabic']?.surahNumber;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 4 : 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.menu_book_rounded,
                label: _getContinueReadingText(),
                onPressed: () async {
                  if (_currentVerses != null &&
                      _currentVerses!['arabic'] != null) {
                    final arabicVerse = _currentVerses!['arabic']!;
                    await Navigator.push(
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
            ),
            const SizedBox(width: 8),
            // Play Button: Higher priority / Larger
            _buildPlayButton(isAudioPlaying),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.auto_awesome_rounded,
                label: _getNewVerseText(),
                onPressed: () async {
                  await _notificationService.clearNotificationVerse();
                  _loadRandomVerses();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isPlaying) {
    return GestureDetector(
      onTap: _playCurrentVerse,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD700), Color(0xFFFFB800)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: const Color(0xFF0D1642),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    // Labels mapping to keep things short and premium
    String displayLabel = label;
    if (_currentLanguage == AppLanguage.arabic) {
      if (label == 'أكمل وردك') displayLabel = 'أكمل الورد';
      if (label == 'آية أخرى') displayLabel = 'آية أخرى';
    } else if (_currentLanguage == AppLanguage.french) {
      if (label == 'Continuer la lecture')
        displayLabel = 'Continuer la lecture';
      if (label == 'Un autre verset') displayLabel = 'Un autre verset';
    } else {
      if (label == 'Continue Reading') displayLabel = 'Continue Reading';
      if (label == 'Another Verse') displayLabel = 'Another Verse';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              const SizedBox(height: 4),
              Text(
                displayLabel,
                style: GoogleFonts.outfit(
                  fontSize: 10, // Slightly smaller to ensure fit
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
