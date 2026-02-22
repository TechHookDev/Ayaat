import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/language_service.dart';
import '../services/preferences_service.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';
import '../widgets/reciter_selector.dart';
import '../widgets/mini_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerseDetailScreen extends StatefulWidget {
  final int surahNumber;
  final int? numberInSurah;
  final AppLanguage language;

  const VerseDetailScreen({
    super.key,
    required this.surahNumber,
    this.numberInSurah,
    required this.language,
  });

  @override
  State<VerseDetailScreen> createState() => _VerseDetailScreenState();
}

class _VerseDetailScreenState extends State<VerseDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _verses = [];
  Map<AppLanguage, String> _surahNames = {};
  String _surahName = ''; // Display name for current language
  bool _isLoading = true;
  String? _error;
  int? _targetVerseIndex;
  final Map<int, GlobalKey> _verseKeys = {};

  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  int? _currentlyPlayingIndex;
  List<Map<String, dynamic>> _bookmarks = [];
  double _fontSize = 24.0;
  final PreferencesService _prefsService = PreferencesService();
  final ProgressService _progressService = ProgressService();

  // Progressive Rendering State
  int _renderedVerseCount = 0;
  static const int _initialRenderAmount = 15;
  static const int _batchRenderAmount = 30;

  // Last read position tracking
  int? _currentVisibleVerseIndex;
  DateTime _lastSaveTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
    _audioService.addListener(_onAudioStateChanged);
    _setupScrollListener();
    _loadSurah();
    _loadPreferences();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients || _verses.isEmpty) return;

      final scrollOffset = _scrollController.offset;

      // SIMPLE: just track which verse index is roughly at top based on scroll
      // Average verse height ~180px with header ~100px
      double headerOffset = (widget.surahNumber != 1 && widget.surahNumber != 9)
          ? 100
          : 0;
      double adjustedOffset = (scrollOffset - headerOffset).clamp(
        0,
        double.infinity,
      );
      int estimatedIndex = (adjustedOffset / 180).floor();

      if (estimatedIndex >= 0 && estimatedIndex < _verses.length) {
        _currentVisibleVerseIndex = estimatedIndex;
      }
    });
  }

  void _debouncedSaveLastReadPosition(int verseIndex) {
    // Only save every 3 seconds to avoid excessive writes
    final now = DateTime.now();
    if (now.difference(_lastSaveTime).inSeconds >= 3) {
      _lastSaveTime = now;
      _saveLastReadPosition(verseIndex);
    }
  }

  Future<void> _saveLastReadPosition(int verseIndex) async {
    if (verseIndex < _verses.length) {
      final verse = _verses[verseIndex];
      final verseNumber = verse['numberInSurah'] as int;
      await _prefsService.saveLastReadPosition(widget.surahNumber, verseNumber);
      debugPrint(
        '📍 Saved reading position: Surah ${widget.surahNumber}, Ayah $verseNumber',
      );
    }
  }

  /// Find the currently visible verse index based on scroll position
  int? _findCurrentVisibleVerseIndex() {
    if (!_scrollController.hasClients || _verses.isEmpty) {
      return null;
    }

    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Target area: top 20% of viewport (where user focus is)
    final targetY = scrollOffset + (viewportHeight * 0.2);

    // Find the verse whose TOP is closest to the target Y position
    // This is more accurate than center-based detection
    int? bestIndex;
    double bestScore = double.infinity;

    for (int i = 0; i < _verses.length; i++) {
      final key = _verseKeys[i];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          final verseTop = position.dy;
          final verseBottom = verseTop + box.size.height;

          // Calculate how well this verse matches the target position
          // Prefer verses whose TOP is near the target Y
          final distanceFromTarget = (verseTop - targetY).abs();

          // Bonus: verse is actually visible on screen
          final isVisible =
              verseBottom > scrollOffset &&
              verseTop < scrollOffset + viewportHeight;

          // Score: distance from target (lower is better)
          // If verse is not visible, add penalty
          double score = distanceFromTarget;
          if (!isVisible) score += 1000; // Heavy penalty for off-screen verses

          if (score < bestScore) {
            bestScore = score;
            bestIndex = i;
          }
        }
      }
    }

    return bestIndex;
  }

  void _onAudioStateChanged() {
    if (mounted) {
      final oldIndex = _currentlyPlayingIndex;
      final newIndex = _audioService.currentAyahIndex;

      setState(() {
        _isPlaying = _audioService.isPlaying;
        _currentlyPlayingIndex = newIndex;

        // IMPORTANT: If the playing verse is beyond our current render batch,
        // we MUST increase _renderedVerseCount immediately so the widget exists.
        if (newIndex != null && newIndex >= _renderedVerseCount) {
          _renderedVerseCount = newIndex + 5;
          if (_renderedVerseCount > _verses.length) {
            _renderedVerseCount = _verses.length;
          }
        }
      });

      // Auto-scroll to the current verse if it changed
      if (newIndex != null && newIndex != oldIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToTargetVerse(newIndex);
          }
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    final fontSize = await _prefsService.getFontSize();
    final bookmarks = await _prefsService.getAllBookmarks();
    if (mounted) {
      setState(() {
        _fontSize = fontSize;
        _bookmarks = bookmarks;
      });
    }
  }

  @override
  void dispose() {
    // Note: Position is saved by PopScope.onPopInvokedWithResult BEFORE dispose() runs
    // Do NOT save here to avoid overwriting the correct position
    _audioService.removeListener(_onAudioStateChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSurah() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get API edition based on selected language
      final edition = _getEdition();

      final response = await http.get(
        Uri.parse(
          'https://api.alquran.cloud/v1/surah/${widget.surahNumber}/$edition',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final surahData = data['data'];
        final verses = surahData['ayahs'] ?? [];

        // Get surah names in all languages
        _surahNames = {
          AppLanguage.arabic: surahData['name'] ?? 'سورة ${widget.surahNumber}',
          AppLanguage.english:
              surahData['englishName'] ?? 'Surah ${widget.surahNumber}',
          AppLanguage.french:
              surahData['englishName'] ?? 'Sourate ${widget.surahNumber}',
        };
        _surahName =
            _surahNames[widget.language] ?? _surahNames[AppLanguage.arabic]!;

        _verses = verses
            .map<Map<String, dynamic>>(
              (v) => {
                'numberInSurah': v['numberInSurah'] as int,
                'text': v['text'] as String,
                'number': v['number'] as int, // GLOBAL ayah number for audio!
              },
            )
            .toList();

        // Debug: Log first few verses to verify global numbers
        debugPrint(
          '📖 Loaded ${_verses.length} verses for Surah ${widget.surahNumber}',
        );
        for (int i = 0; i < (_verses.length < 5 ? _verses.length : 5); i++) {
          debugPrint(
            '  Verse ${i + 1}: numberInSurah=${_verses[i]['numberInSurah']}, global=${_verses[i]['number']}',
          );
        }

        // Find target verse index
        _targetVerseIndex = null;
        if (widget.numberInSurah != null) {
          for (int i = 0; i < _verses.length; i++) {
            if (_verses[i]['numberInSurah'] == widget.numberInSurah) {
              _targetVerseIndex = i;
              _verseKeys[i] = GlobalKey();
              debugPrint('✓ Target verse ${widget.numberInSurah} at index $i');
              break;
            }
          }
        }

        setState(() {
          // Instead of finishing loading here, we start the rendering pipeline
        });

        // Set initial visible verse index (for PopScope to use later)
        _currentVisibleVerseIndex = _targetVerseIndex ?? 0;

        _startProgressiveRendering();

        // Scroll after build - wait for SingleChildScrollView to render
        if (_targetVerseIndex != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              _scrollToTargetVerse(_targetVerseIndex!);
            });
          });
        }
      } else {
        throw Exception('Failed to load surah: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startProgressiveRendering() {
    if (!mounted) return;

    // If we have a target verse, we need to render at least up to that verse immediately
    int targetRender = _verses.length;
    if (_targetVerseIndex != null) {
      targetRender = _targetVerseIndex! + _initialRenderAmount;
      if (targetRender > _verses.length) targetRender = _verses.length;
    } else {
      targetRender = _initialRenderAmount;
      if (targetRender > _verses.length) targetRender = _verses.length;
    }

    setState(() {
      _isLoading = false;
      _renderedVerseCount = targetRender;
    });

    _renderNextBatch();
  }

  void _renderNextBatch() {
    if (!mounted || _renderedVerseCount >= _verses.length) return;

    Future.microtask(() {
      if (mounted) {
        setState(() {
          _renderedVerseCount += _batchRenderAmount;
          if (_renderedVerseCount > _verses.length) {
            _renderedVerseCount = _verses.length;
          }
        });
        // Continue rendering next batch in the next microtask
        if (_renderedVerseCount < _verses.length) {
          _renderNextBatch();
        }
      }
    });
  }

  String _getEdition() {
    switch (widget.language) {
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.english:
        return 'en.sahih';
      case AppLanguage.french:
        return 'fr.hamidullah';
    }
  }

  String _getSurahName(dynamic surahData) {
    switch (widget.language) {
      case AppLanguage.arabic:
        return surahData['name'] ?? 'سورة ${widget.surahNumber}';
      case AppLanguage.english:
        return surahData['englishName'] ?? 'Surah ${widget.surahNumber}';
      case AppLanguage.french:
        // French API might not have frenchName, fallback to englishName
        return surahData['englishName'] ?? 'Sourate ${widget.surahNumber}';
    }
  }

  void _scrollToTargetVerse(int verseIndex) {
    if (!_scrollController.hasClients) return;

    final key = _verseKeys[verseIndex];
    if (key == null) return;

    final context = key.currentContext;
    if (context == null) {
      // If context is null, it might be because the widget is still building
      // after our setState above. we can try one more delay.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          final retryContext = key.currentContext;
          if (retryContext != null) {
            Scrollable.ensureVisible(
              retryContext,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              alignment: 0.1,
            );
          }
        }
      });
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      alignment: 0.1, // 10% from top (better focus)
    );

    debugPrint('✓ Scrolled to verse index $verseIndex');
  }

  Future<void> _toggleBookmark(int verseInSurah, int globalNumber) async {
    final isCurrentlyBookmarked = await _prefsService.isBookmarked(
      widget.surahNumber,
      verseInSurah,
    );

    if (isCurrentlyBookmarked) {
      await _prefsService.removeBookmarkByPosition(
        widget.surahNumber,
        verseInSurah,
      );
    } else {
      await _prefsService.addBookmark(widget.surahNumber, verseInSurah);
      // Gamification: Give points for intentional bookmarking
      await _progressService.addPoints(10);
    }

    // Refresh bookmarks list
    final bookmarks = await _prefsService.getAllBookmarks();
    if (mounted) setState(() => _bookmarks = bookmarks);
  }

  Future<void> _changeFontSize(double delta) async {
    // Save current visible verse index before changing font
    final currentVerseIndex =
        _currentVisibleVerseIndex ?? _getCurrentVisibleVerseIndex();

    final newSize = (_fontSize + delta).clamp(16.0, 40.0);
    await _prefsService.saveFontSize(newSize);
    setState(() => _fontSize = newSize);

    // After rebuild, scroll back to the same verse
    if (currentVerseIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToTargetVerse(currentVerseIndex);
        }
      });
    }
  }

  /// Get the currently visible verse index based on scroll position
  int? _getCurrentVisibleVerseIndex() {
    if (!_scrollController.hasClients || _verses.isEmpty) return null;

    final scrollOffset = _scrollController.offset;
    final viewportDimension = _scrollController.position.viewportDimension;
    final centerOffset = scrollOffset + (viewportDimension * 0.3);

    // Find the verse closest to this offset
    for (int i = 0; i < _verseKeys.length; i++) {
      final key = _verseKeys[i];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          if (position.dy >= 0 && position.dy <= viewportDimension) {
            return i;
          }
        }
      }
    }
    return null;
  }

  Future<void> _playAudio(
    int globalVerseNumber,
    int index, {
    bool continuousMode = true, // Default to continuous playback
    bool forceRestart = false,
  }) async {
    try {
      if (!forceRestart && _currentlyPlayingIndex == index && _isPlaying) {
        await _audioService.pause();
      } else {
        // Debug logging
        debugPrint(
          '▶️ Playing Surah ${widget.surahNumber}, Ayah index: $index, Global: $globalVerseNumber',
        );

        // Gamification: Give points for audio engagement
        await _progressService.addPoints(5);
        await _audioService.playAyah(
          globalAyahNumber: globalVerseNumber,
          surahNumber: widget.surahNumber,
          ayahIndex: index,
          surahNames: _surahNames,
          verses: _verses,
          continuousMode: continuousMode,
        );
        if (mounted) {
          setState(() {
            _currentlyPlayingIndex = index;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio failed: $e', style: GoogleFonts.outfit()),
          ),
        );
      }
    }
  }

  Future<void> _playSurah() async {
    if (_verses.isEmpty) return;

    try {
      // Gamification: Give points for playing entire surah
      await _progressService.addPoints(10);
      await _audioService.playSurah(
        surahNumber: widget.surahNumber,
        surahNames: _surahNames,
        verses: _verses,
      );
      if (mounted) {
        setState(() {
          _currentlyPlayingIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio failed: $e', style: GoogleFonts.outfit()),
          ),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    await _audioService.stop();
    if (mounted) {
      setState(() {
        _currentlyPlayingIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Use tracked visible verse index, or calculate from scroll
          int verseIndex = _currentVisibleVerseIndex ?? 0;

          // Validate the index
          if (verseIndex >= _verses.length) {
            verseIndex = _verses.length - 1;
          }

          final verse = _verses[verseIndex];
          final ayahNumber = verse['numberInSurah'] as int;

          // AWAIT the save to ensure it completes before navigating
          await _prefsService.saveLastReadPosition(
            widget.surahNumber,
            ayahNumber,
          );
          debugPrint(
            '💾 SAVED: Surah ${widget.surahNumber}, Ayah $ayahNumber (index: $verseIndex)',
          );
        }
      },
      child: Scaffold(
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
                final isLandscape = orientation == Orientation.landscape;
                return Column(
                  children: [
                    _buildHeader(isLandscape),
                    if (_error != null)
                      Expanded(
                        child: Center(
                          child: Text(
                            _error!,
                            style: GoogleFonts.amiri(
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      )
                    else if (_isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    else
                      Expanded(child: _buildVersesList()),
                    // Mini Player - shows when audio is playing
                    MiniPlayer(
                      audioService: _audioService,
                      language: widget.language,
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLandscape) {
    if (isLandscape) {
      // Compact horizontal layout for landscape
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white70,
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                _surahName,
                style: GoogleFonts.amiri(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.left,
                textDirection: widget.language == AppLanguage.arabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Font Size Controls inline
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _changeFontSize(-2),
                  icon: const Icon(
                    Icons.remove,
                    color: Colors.white70,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  'A',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fontSize.toInt()}',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'A',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeFontSize(2),
                  icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default Portrait layout
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _surahName,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: widget.language == AppLanguage.arabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Font Size Controls and Stop Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _changeFontSize(-2),
                icon: const Icon(Icons.remove, color: Colors.white70, size: 20),
              ),
              Text(
                'A',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                '${_fontSize.toInt()}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'A',
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => _changeFontSize(2),
                icon: const Icon(Icons.add, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reciter Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ReciterSelector(
              audioService: _audioService,
              language: widget.language,
              onReciterChanged: () {
                // Restart current ayah with new reciter if we were playing or had an index
                if (_currentlyPlayingIndex != null) {
                  final verse = _verses[_currentlyPlayingIndex!];
                  final globalNumber = verse['number'] as int;
                  _playAudio(
                    globalNumber,
                    _currentlyPlayingIndex!,
                    forceRestart: true,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getPlaySurahText() {
    switch (widget.language) {
      case AppLanguage.arabic:
        return 'تشغيل';
      case AppLanguage.french:
        return 'Lire';
      case AppLanguage.english:
        return 'Play';
    }
  }

  String _getPauseText() {
    switch (widget.language) {
      case AppLanguage.arabic:
        return 'إيقاف';
      case AppLanguage.french:
        return 'Pause';
      case AppLanguage.english:
        return 'Pause';
    }
  }

  Widget _buildVersesList() {
    // Use SingleChildScrollView with Column for 100% reliability
    // We render progressively to prevent UI freezing on huge Surahs
    final versesToRender = _verses.take(_renderedVerseCount).toList();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Bismillah header (except Surah 9)
          if (widget.surahNumber != 9) _buildBismillah(),

          // Render the batches
          ...versesToRender
              .asMap()
              .entries
              .where((entry) {
                // Completely hide Verse 1 (index 0) of Al-Fatiha to remove the duplicate Bismillah block
                if (widget.surahNumber == 1 && entry.key == 0) return false;
                return true;
              })
              .map((entry) {
                return _buildVerseItem(entry.key, entry.value);
              }),

          // Show subtle loading indicator at bottom if still rendering in background
          if (_renderedVerseCount < _verses.length)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBismillah() {
    return Column(
      children: [
        Text(
          '﷽',
          style: GoogleFonts.amiri(
            fontSize: 32,
            color: const Color(0xFFFFD700),
          ),
        ),
        const Divider(color: Colors.white24, height: 32),
      ],
    );
  }

  Widget _buildVerseItem(int verseIndex, Map<String, dynamic> verse) {
    final isTarget = verseIndex == _targetVerseIndex;
    final verseNumber = verse['numberInSurah'] as int;
    final globalNumber =
        verse['number'] ??
        0; // Guard for global number if missing in base API mapping, though we added it in MushafPro

    // Shift display verse number for Al-Fatiha so Al-Hamdu lillahi is Verse 1
    final int displayVerseNumber = (widget.surahNumber == 1 && verseNumber > 1)
        ? verseNumber - 1
        : verseNumber;

    String text = verse['text'];

    // Remove bismillah from first verse EXCEPT Surah 9 (Tawbah).
    // Note: User reported Fatiha (1) had duplicate Bismillah, so we must strip it there too.
    if (verseIndex == 0 &&
        widget.surahNumber != 9 &&
        widget.language == AppLanguage.arabic) {
      text = _removeBismillah(text);
    }

    final goldColor = const Color(0xFFFFD700);
    final textColor = isTarget ? goldColor : Colors.white;
    final numberColor = isTarget ? goldColor : Colors.white54;

    final isBookmarked = _bookmarks.any(
      (b) => b['surah'] == widget.surahNumber && b['verse'] == verseNumber,
    );
    // Check if this specific verse is playing from audio service
    final bool isThisVersePlaying =
        _audioService.currentSurahNumber == widget.surahNumber &&
        _audioService.currentAyahIndex == verseIndex &&
        _audioService.isPlaying;

    return Column(
      key: _verseKeys.putIfAbsent(verseIndex, () => GlobalKey()),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Action Bar (Audio + Bookmark)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Simple Play/Pause Button
            GestureDetector(
              onTap: () => _playAudio(globalNumber, verseIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isThisVersePlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: isThisVersePlaying
                      ? const Color(0xFFFFD700)
                      : Colors.white54,
                  size: 28,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _toggleBookmark(verseNumber, globalNumber),
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? const Color(0xFFFFD700) : Colors.white24,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        Text(
          text,
          style: widget.language == AppLanguage.arabic
              ? GoogleFonts.amiri(
                  fontSize: _fontSize,
                  color: textColor,
                  height: 1.8,
                )
              : GoogleFonts.outfit(
                  fontSize: _fontSize - 6,
                  color: textColor,
                  height: 1.6,
                ),
          textAlign: TextAlign.center,
          textDirection: widget.language == AppLanguage.arabic
              ? TextDirection.rtl
              : TextDirection.ltr,
        ),
        const SizedBox(height: 16),
        Text(
          '$displayVerseNumber',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: numberColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Colors.white24, height: 32),
      ],
    );
  }

  String _getPlayingText() {
    switch (widget.language) {
      case AppLanguage.arabic:
        return 'يُتلى الآن';
      case AppLanguage.english:
        return 'Playing';
      case AppLanguage.french:
        return 'En cours';
    }
  }

  String _removeBismillah(String text) {
    text = text.replaceAll('\ufeff', '');

    if (text.contains('بسم') || text.contains('بِسْمِ')) {
      const targetSkeleton = "بسماللهالرحمنالرحيم";
      int targetIdx = 0;
      int textIdx = 0;

      while (textIdx < text.length && targetIdx < targetSkeleton.length) {
        final charCode = text.codeUnitAt(textIdx);
        final char = text[textIdx];

        if (char == targetSkeleton[targetIdx]) {
          targetIdx++;
          textIdx++;
        } else if (charCode == 0x20 ||
            (charCode >= 0x064B && charCode <= 0x065F) ||
            charCode == 0x0670 ||
            charCode == 0x06D6 ||
            charCode == 0x06E5 ||
            charCode == 0x06E6 ||
            charCode == 1600) {
          textIdx++;
        } else {
          break;
        }
      }

      if (targetIdx >= targetSkeleton.length) {
        while (textIdx < text.length) {
          final code = text.codeUnitAt(textIdx);
          if (code == 0x20 ||
              (code >= 0x064B && code <= 0x0652) ||
              code == 0x0670) {
            textIdx++;
          } else {
            break;
          }
        }
        return text.substring(textIdx).trim();
      }
    }

    return text;
  }
}
