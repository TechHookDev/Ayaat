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
import '../services/progress_service.dart';

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
  final ProgressService _progressService = ProgressService();
  final AudioService _audioService = AudioService();
  AppLanguage _currentLanguage = AppLanguage.arabic;
  Map<String, Verse>? _currentVerses;
  bool _isLoading = true;
  String? _error;

  // Progress State
  int _currentStreak = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
    _audioService.addListener(_onAudioStateChanged);
    _loadLanguage();
    _loadProgress();
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

  Future<void> _loadProgress() async {
    // Check if streak was broken before fetching
    await _progressService.checkStreakStatus();

    final streak = await _progressService.getCurrentStreak();
    final points = await _progressService.getTotalPoints();

    if (mounted) {
      setState(() {
        _currentStreak = streak;
        _totalPoints = points;
      });
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
        await _loadProgress();
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
        await _loadProgress();
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
    await _loadProgress();
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

  void _showPointsGuide() {
    final isArabic = _currentLanguage == AppLanguage.arabic;
    final isFrench = _currentLanguage == AppLanguage.french;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Color(0xFFFFD700), width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              isArabic
                  ? 'كيف تكسب نقاط آيات؟'
                  : (isFrench
                        ? 'Comment gagner des points ?'
                        : 'How to earn Points?'),
              style: GoogleFonts.amiri(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGuideItem(
                      Icons.local_fire_department,
                      Colors.orange,
                      isArabic
                          ? 'زيارة يومية'
                          : (isFrench ? 'Visite quotidienne' : 'Daily Visit'),
                      isArabic
                          ? 'افتح المصحف يومياً (+50 XP)'
                          : (isFrench
                                ? 'Ouvrez le Mushaf chaque jour (+50 XP)'
                                : 'Open the Mushaf daily (+50 XP)'),
                    ),
                    _buildGuideItem(
                      Icons.headset,
                      const Color(0xFFFFD700),
                      isArabic
                          ? 'استماع للآيات'
                          : (isFrench
                                ? 'Écoute de versets'
                                : 'Audio Engagement'),
                      isArabic
                          ? 'استمع لآية كاملة (+5 XP)'
                          : (isFrench
                                ? 'Écoutez un verset complet (+5 XP)'
                                : 'Listen to a full verse (+5 XP)'),
                    ),
                    _buildGuideItem(
                      Icons.bookmark,
                      Colors.blueAccent,
                      isArabic
                          ? 'حفظ العلامات'
                          : (isFrench ? 'Gestion des favoris' : 'Bookmarking'),
                      isArabic
                          ? 'حفظ موضع القراءة (+10 XP)'
                          : (isFrench
                                ? 'Enregistrez votre position (+10 XP)'
                                : 'Save your reading position (+10 XP)'),
                    ),
                    _buildGuideItem(
                      Icons.stars,
                      const Color(0xFFFFD700),
                      isArabic
                          ? 'إتمام السورة'
                          : (isFrench
                                ? 'Achèvement de sourate'
                                : 'Surah Completion'),
                      isArabic
                          ? 'الاستماع لنهاية السورة (+50 XP)'
                          : (isFrench
                                ? 'Ecoutez jusqu\'à la fin (+50 XP)'
                                : 'Finish audio for a full Surah (+50 XP)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isArabic ? 'فهمت' : (isFrench ? 'Compris' : 'Understood'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        _buildStatsDashboard(),
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
                _buildStatsDashboard(),
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
                  // Refresh progress stats after returning from Surah List (and reading ayahs)
                  await _loadProgress();
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
                await _loadProgress();

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

  Widget _buildStatsDashboard() {
    String streakLabel = _currentLanguage == AppLanguage.arabic
        ? 'يوم متتالي'
        : _currentLanguage == AppLanguage.french
        ? 'Jours consécutifs'
        : 'Day Streak';
    String pointsLabel = _currentLanguage == AppLanguage.arabic
        ? 'نقطة آيات'
        : _currentLanguage == AppLanguage.french
        ? 'Points Ayaat'
        : 'Ayaat Points';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 🔥 Streak Stat
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_currentStreak',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    streakLabel,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Container(height: 30, width: 1, color: Colors.white10),

          // 📖 Ayahs Read Stat
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$_totalPoints',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _showPointsGuide,
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.white38,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    pointsLabel,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
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
      await _progressService.addPoints(5);

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
      await _loadProgress();
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
                  if (_currentVerses != null && _currentVerses!['arabic'] != null) {
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
                    await _loadProgress();
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
      if (label == 'Continuer la lecture') displayLabel = 'Continuer la lecture';
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
