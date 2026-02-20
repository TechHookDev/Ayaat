import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/language_service.dart';
import '../services/quran_api.dart';
import '../services/preferences_service.dart';
import '../services/progress_service.dart';

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
  final QuranApiService _apiService = QuranApiService();
  final PreferencesService _prefs = PreferencesService();
  final ProgressService _progress = ProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<dynamic> _arabicVerses = [];
  List<dynamic> _translationVerses = [];
  String _surahName = '';
  
  bool _isLoading = true;
  String? _error;
  int? _targetVerseIndex;
  
  final Map<int, GlobalKey> _verseKeys = {};
  
  // Settings State
  double _fontSize = 24.0;
  Map<String, int>? _bookmark;
  
  // Audio State
  int? _currentlyPlayingIndex;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadSurahAndPreferences();
    // Add habit-building streak update when opening Mushaf
    _progress.incrementStreakOnly();
  }

  void _initAudio() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            // Reward XP for completing an audio recitation
            _progress.addPoints(5);
            
            // Auto-advance to next verse!
            if (_currentlyPlayingIndex != null && _currentlyPlayingIndex! < _arabicVerses.length - 1) {
              final nextIndex = _currentlyPlayingIndex! + 1;
              final nextGlobalNumber = _arabicVerses[nextIndex]['number'] as int;
              _playAudio(nextGlobalNumber, nextIndex, autoPlay: true);
            } else {
              // Reached the end of the Surah
              _progress.addPoints(50); // Surah completion bonus
              _currentlyPlayingIndex = null;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSurahAndPreferences() async {
    // Zero-Lag: Check cache BEFORE setting loading state
    final cacheKey = '${widget.surahNumber}-${widget.language.name}';
    final cachedData = QuranApiService.getSurahCache()[cacheKey];

    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _arabicVerses = cachedData['arabic']!;
          _translationVerses = cachedData['translation']!;
          _isLoading = false;
          _error = null;
          
          _verseKeys.clear();
          for (int i = 0; i < _arabicVerses.length; i++) {
            _verseKeys[i] = GlobalKey();
          }
        });
      }
      
      // Load preferences and metadata in background
      _prefs.getFontSize().then((size) {
        if (mounted) setState(() => _fontSize = size);
      });
      _prefs.getBookmark().then((bm) {
         if (mounted) setState(() => _bookmark = bm);
      });
      _apiService.getSurahs(widget.language).then((list) {
         if (mounted && list.isNotEmpty) {
           try {
             final surahMeta = list.firstWhere((s) => s['number'] == widget.surahNumber);
             setState(() {
               _surahName = widget.language == AppLanguage.arabic ? surahMeta['name'] : surahMeta['englishName'];
             });
           } catch (_) {}
         }
      });

      // Precision Landing for cached data
      if (widget.numberInSurah != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          int targetIdx = widget.numberInSurah! - 1;
          // Al-Fatiha: if targeting 1, we want index 1 (since 0 is hidden)
          if (widget.surahNumber == 1 && widget.numberInSurah == 1) targetIdx = 1;
          
          setState(() => _targetVerseIndex = targetIdx);
          _scrollToTargetVerse(targetIdx);
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Parallelize all data fetching for zero-lag startup
      final List<dynamic> results = await Future.wait([
        _prefs.getFontSize(),
        _prefs.getBookmark(),
        _apiService.getSurahWithTranslation(widget.surahNumber, widget.language),
        _apiService.getSurahs(widget.language),
      ]);

      final double savedFontSize = results[0];
      final Map<String, int>? bookmark = results[1];
      final Map<String, List<dynamic>> data = results[2];
      final List<dynamic> surahs = results[3];

      final arabicVerses = data['arabic']!;
      final translationVerses = data['translation']!;

      String surahName = 'Surah ${widget.surahNumber}';
      try {
        final surahMeta = surahs.firstWhere((s) => s['number'] == widget.surahNumber);
        surahName = widget.language == AppLanguage.arabic ? surahMeta['name'] : surahMeta['englishName'];
      } catch (_) {}

      if (mounted) {
        setState(() {
          _fontSize = savedFontSize;
          _bookmark = bookmark;
          _arabicVerses = arabicVerses;
          _translationVerses = translationVerses;
          _surahName = surahName;
          _isLoading = false;
          
          _verseKeys.clear();
          for (int i = 0; i < _arabicVerses.length; i++) {
            _verseKeys[i] = GlobalKey();
          }
          
          if (widget.numberInSurah != null) {
            int targetIdx = widget.numberInSurah! - 1;
            if (widget.surahNumber == 1 && widget.numberInSurah == 1) targetIdx = 1;
            
            _targetVerseIndex = targetIdx;
            WidgetsBinding.instance.addPostFrameCallback((_) {
               _scrollToTargetVerse(_targetVerseIndex!);
            });
          }
        });
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

  void _scrollToTargetVerse(int index) {
    if (!_scrollController.hasClients) return;
    if (index < 0 || index >= _arabicVerses.length) return;
    
    // Phase 1: Surgical Direct-Offset Navigation
    // We calculate the EXACT pixel height of the viewport content.
    final hasBismillah = widget.surahNumber != 9 && widget.surahNumber != 1;
    double targetOffset = 10.0; // ListView top padding
    
    if (hasBismillah) {
       // Precise TextPainter for Bismillah block ('﷽' at size 32)
       final bismillahPainter = TextPainter(
          text: TextSpan(
            text: '﷽',
            style: GoogleFonts.amiri(fontSize: 32, color: const Color(0xFFFFD700)),
          ),
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: MediaQuery.of(context).size.width);
       targetOffset += bismillahPainter.height + 48; // Padding vertical 24*2
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    // Total horizontal padding: 20*2 (ListView) + 24*2 (Card) = 88
    final double contentWidth = screenWidth - 88;

    for (int i = 0; i < index; i++) {
        final text = widget.language == AppLanguage.arabic ? _arabicVerses[i]['text'] : _translationVerses[i]['text'];
        
        String processedText = text;
        if (i == 0 && widget.surahNumber != 9 && widget.surahNumber != 1) {
           processedText = _removeBismillah(text);
        }

        final painter = TextPainter(
          text: TextSpan(
            text: processedText,
            style: GoogleFonts.amiri(
              fontSize: (widget.surahNumber == 1 && i == 0) ? 32 : _fontSize, 
              height: 1.8
            ),
          ),
          textDirection: widget.language == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr,
        )..layout(maxWidth: contentWidth);

        // Fixed heights: Container Padding (48) + Row (48) + SizedBox (24) + Margin (16) + Borders (4) = 140
        if (processedText.isNotEmpty) {
          targetOffset += 140 + painter.height; 
        } else {
          // Empty text -> no SizedBox, no Text
          targetOffset += 140 - 24; 
        }
    }
    
    // Surgical Landing with centering buffer
    // Subtract 20px so the verse isn't touching the status bar area
    final finalOffset = (targetOffset - 20).clamp(0.0, _scrollController.position.maxScrollExtent);
    
    _scrollController.animateTo(
      finalOffset,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOutQuart,
    );
  }


  // Settings Actions
  Future<void> _toggleBookmark(int verseInSurah, int globalNumber) async {
    final isCurrentlyBookmarked = _bookmark?['surah'] == widget.surahNumber && _bookmark?['verse'] == verseInSurah;
    
    final removedMsg = widget.language == AppLanguage.arabic ? 'تم إزالة موضع القراءة' : widget.language == AppLanguage.french ? 'Position de lecture effacée' : 'Reading position cleared';
    final savedMsg = widget.language == AppLanguage.arabic ? 'تم حفظ موضع القراءة' : widget.language == AppLanguage.french ? 'Position de lecture enregistrée' : 'Reading position saved';

    SnackBar createSnackBar(String msg, IconData icon, Color color) {
      return SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14))),
          ],
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        duration: const Duration(seconds: 2),
      );
    }

    if (isCurrentlyBookmarked) {
      await _prefs.removeBookmark();
      if (mounted) {
        setState(() {
          _bookmark = null;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          createSnackBar(removedMsg, Icons.bookmark_border, Colors.white54)
        );
      }
    } else {
      await _prefs.saveBookmark(widget.surahNumber, verseInSurah);
      
      // Reward points for intentionally saving a bookmark
      await _progress.addPoints(10);
      
      final bm = await _prefs.getBookmark();
      if (mounted) {
        setState(() {
          _bookmark = bm;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          createSnackBar(savedMsg, Icons.bookmark, const Color(0xFFFFD700))
        );
      }
    }
  }

  Future<void> _changeFontSize(double delta) async {
    double newSize = (_fontSize + delta).clamp(16.0, 48.0);
    setState(() {
      _fontSize = newSize;
    });
    await _prefs.saveFontSize(newSize);
  }

  Future<void> _playAudio(int globalAyahNumber, int index, {bool autoPlay = false}) async {
    if (!autoPlay && _currentlyPlayingIndex == index && _isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() {
        _currentlyPlayingIndex = index;
      });
      final url = _apiService.getAudioUrl(globalAyahNumber);
      await _audioPlayer.play(UrlSource(url));
      
      // Auto-scroll up to the new verse if taking over dynamically
      if (autoPlay) {
         _scrollToTargetVerse(index);
      }
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
              if (!_isLoading && _error == null) _buildControlBar(),
              if (_error != null)
                Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
              else if (_isLoading)
                Expanded(
                  child: Center(
                    child: FutureBuilder(
                      future: Future.delayed(const Duration(milliseconds: 150)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return const CircularProgressIndicator(color: Color(0xFFFFD700));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                )
              else
                Expanded(child: _buildVersesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          ),
          Expanded(
            child: Text(
              _surahName,
              style: GoogleFonts.amiri(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5).copyWith(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Font Size Controls
          Row(
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
                style: GoogleFonts.outfit(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold),
              ),
               const SizedBox(width: 12),
               Text(
                'A',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _changeFontSize(2),
                icon: const Icon(Icons.add, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersesList() {
    final hasBismillah = widget.surahNumber != 9 && widget.surahNumber != 1;
    final totalItems = _arabicVerses.length + (hasBismillah ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 2000, // Pre-renders items for silk-smooth navigation
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 60),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (hasBismillah) {
          if (index == 0) return _buildBismillah();
          
          final verseIndex = index - 1;
          return _buildVerseItem(verseIndex, _arabicVerses[verseIndex], _translationVerses[verseIndex]);
        } else {
          return _buildVerseItem(index, _arabicVerses[index], _translationVerses[index]);
        }
      },
    );
  }


  Widget _buildBismillah() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '﷽',
          style: GoogleFonts.amiri(
            fontSize: 32,
            color: const Color(0xFFFFD700),
          ),
        ),
      ),
    );
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
        } else if (charCode == 0x20 || (charCode >= 0x064B && charCode <= 0x065F) || charCode == 0x0670 || charCode == 0x06D6 || charCode == 0x06E5 || charCode == 0x06E6 || charCode == 1600) {
          textIdx++;
        } else {
          break;
        }
      }
      if (targetIdx >= targetSkeleton.length) {
        while (textIdx < text.length) {
           final code = text.codeUnitAt(textIdx);
           if (code == 0x20 || (code >= 0x064B && code <= 0x0652) || code == 0x0670) {
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

  Widget _buildVerseItem(int index, dynamic arabicVerse, dynamic translationVerse) {
    final verseInSurah = arabicVerse['numberInSurah'] as int;
    final globalNumber = arabicVerse['number'] as int;

    String arabicText = arabicVerse['text'];
    // Strip Bismillah from the first verse of ALL surahs (including Fatiha)
    if (index == 0 && widget.surahNumber != 9) {
      final stripped = _removeBismillah(arabicText);
      arabicText = stripped;
    }

    final isBookmarked = _bookmark?['surah'] == widget.surahNumber && _bookmark?['verse'] == verseInSurah;
    final isTarget = index == _targetVerseIndex;
    final isPlaying = _currentlyPlayingIndex == index && _isPlaying;
    
    final bool showArabic = widget.language == AppLanguage.arabic;
    String displayText = showArabic ? arabicText : translationVerse['text'];
    
    if (index == 0 && widget.surahNumber != 9 && widget.surahNumber != 1) {
       displayText = _removeBismillah(displayText);
    }

    return RepaintBoundary(
      child: AnimatedContainer(
        key: _verseKeys[index],
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(vertical: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isTarget ? const Color(0xFFFFD700).withOpacity(0.08) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTarget ? const Color(0xFFFFD700) : Colors.white10.withOpacity(0.05),
            width: isTarget ? 2.0 : 1.0, 
          ),
          boxShadow: isTarget ? [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.12),
              blurRadius: 15,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Verse Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Play / Pause Audio
                  IconButton(
                    onPressed: () => _playAudio(globalNumber, index),
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: isPlaying ? const Color(0xFFFFD700) : Colors.white54,
                      size: 32,
                    ),
                  ),
                  
                  // Ayah Number Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.surahNumber == 1 ? '${verseInSurah - 1}' : '$verseInSurah',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFFD700),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
  
                  // Bookmark Icon
                  IconButton(
                    onPressed: () => _toggleBookmark(verseInSurah, globalNumber),
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? const Color(0xFFFFD700) : Colors.white54,
                      size: 28,
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Verse Content text
            if (displayText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  displayText,
                  style: GoogleFonts.amiri(
                    fontSize: (widget.surahNumber == 1 && index == 0) ? 32 : _fontSize,
                    color: (widget.surahNumber == 1 && index == 0) ? const Color(0xFFFFD700) : Colors.white,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: showArabic ? TextDirection.rtl : TextDirection.ltr,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
