import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/quran_api.dart';
import '../services/language_service.dart';
import '../services/preferences_service.dart';
import 'verse_detail_screen.dart';
import '../main.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> with RouteAware {
  final QuranApiService _apiService = QuranApiService();
  final LanguageService _languageService = LanguageService();
  final PreferencesService _prefs = PreferencesService();

  List<dynamic> _surahs = [];
  List<dynamic> _filteredSurahs = [];
  bool _isLoading = true;
  String? _error;
  AppLanguage _currentLanguage = AppLanguage.arabic;
  String _searchQuery = '';
  List<Map<String, dynamic>> _bookmarks = [];
  Map<String, dynamic>? _lastReadPosition;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh data when returning from VerseDetailScreen
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final lang = await _languageService.getCurrentLanguage();
      final bookmarks = await _prefs.getAllBookmarks();
      final lastRead = await _prefs.getLastReadPosition();

      setState(() => _currentLanguage = lang);

      final surahs = await _apiService.getSurahs(lang);
      if (mounted) {
        setState(() {
          _surahs = surahs;
          _filteredSurahs = surahs;
          _bookmarks = bookmarks;
          _lastReadPosition = lastRead;
          _isLoading = false;
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

  String _stripDiacritics(String text) {
    var s = text;
    // Remove Arabic diacritics (tashkeel), including shadda and maddah
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    // Normalize Alef variants to bare Alef (including Alef Wasla ٱ)
    s = s.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
    // Normalize Ta Marbuta to Ha
    s = s.replaceAll('ة', 'ه');
    // Remove the prefix 'سورة ' or 'سوره ' for cleaner matching
    s = s.replaceAll('سورة ', '').replaceAll('سوره ', '');
    return s.trim();
  }

  void _filterSurahs(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSurahs = _surahs;
      } else {
        final searchLower = _stripDiacritics(query.toLowerCase());
        _filteredSurahs = _surahs.where((surah) {
          final englishName = surah['englishName'].toString().toLowerCase();
          final arabicName = _stripDiacritics(surah['name'].toString());
          final translationName = surah['englishNameTranslation']
              .toString()
              .toLowerCase();

          return englishName.contains(searchLower) ||
              arabicName.contains(searchLower) ||
              translationName.contains(searchLower);
        }).toList();
      }
    });
  }

  // Refreshes bookmark when popping back
  Future<void> _navigateToSurah(int surahNumber, {int? numberInSurah}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerseDetailScreen(
          surahNumber: surahNumber,
          numberInSurah: numberInSurah,
          language: _currentLanguage,
        ),
      ),
    );
    // Wait a tiny bit for SharedPreferences to flush
    await Future.delayed(const Duration(milliseconds: 50));
    // Refresh bookmarks and last read position when returning
    final bookmarks = await _prefs.getAllBookmarks();
    final lastRead = await _prefs.getLastReadPosition();
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
        _lastReadPosition = lastRead;
      });
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
              final isLandscape = orientation == Orientation.landscape;
              return Column(
                children: [
                  _buildHeader(isLandscape),
                  _buildSearchBar(isLandscape),
                  if (_bookmarks.isNotEmpty && _searchQuery.isEmpty)
                    _buildBookmarksSection(isLandscape),
                  if (_lastReadPosition != null && _searchQuery.isEmpty)
                    _buildContinueReadingBanner(isLandscape),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFD700),
                            ),
                          )
                        : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : _buildSurahList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_currentLanguage) {
      case AppLanguage.french:
        return 'Le Saint Coran';
      case AppLanguage.english:
        return 'The Holy Quran';
      case AppLanguage.arabic:
      default:
        return 'المصحف الشريف';
    }
  }

  String _getSearchHint() {
    switch (_currentLanguage) {
      case AppLanguage.french:
        return 'Rechercher une sourate';
      case AppLanguage.english:
        return 'Search Surah';
      case AppLanguage.arabic:
      default:
        return 'ابحث عن سورة';
    }
  }

  Widget _buildHeader(bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 5 : 20,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white70,
              size: isLandscape ? 20 : 24,
            ),
          ),
          Expanded(
            child: Text(
              _getHeaderTitle(),
              style: GoogleFonts.amiri(
                fontSize: isLandscape ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance back button
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 0 : 10,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: TextField(
          onChanged: _filterSurahs,
          style: GoogleFonts.outfit(color: Colors.white),
          textAlign: _currentLanguage == AppLanguage.arabic ? TextAlign.right : TextAlign.left,
          textDirection: _currentLanguage == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr,
          decoration: InputDecoration(
            hintText: _getSearchHint(),
            hintStyle: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: isLandscape ? 14 : 16,
            ),
            // Surgical fix: Move icon to right (suffix) for Arabic, left (prefix) for others
            prefixIcon: _currentLanguage == AppLanguage.arabic 
              ? null 
              : Icon(Icons.search, color: Colors.white54, size: isLandscape ? 20 : 24),
            suffixIcon: _currentLanguage == AppLanguage.arabic 
              ? Icon(Icons.search, color: Colors.white54, size: isLandscape ? 20 : 24)
              : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isLandscape ? 10 : 15,
            ),
            isDense: isLandscape,
          ),
        ),
      ),
    );
  }

  /// Build the bookmarks section with multiple bookmarks
  Widget _buildBookmarksSection(bool isLandscape) {
    final isArabic = _currentLanguage == AppLanguage.arabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: EdgeInsets.fromLTRB(20, isLandscape ? 5 : 10, 20, 8),
          child: Text(
            isArabic
                ? 'العلامات المرجعية (${_bookmarks.length})'
                : (_currentLanguage == AppLanguage.french
                      ? 'Signets (${_bookmarks.length})'
                      : 'Bookmarks (${_bookmarks.length})'),
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Scrollable list of bookmarks
        SizedBox(
          height: isLandscape ? 55 : 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _bookmarks.length,
            itemBuilder: (context, index) {
              return _buildBookmarkCard(_bookmarks[index], isLandscape);
            },
          ),
        ),
      ],
    );
  }

  /// Build a single bookmark card
  Widget _buildBookmarkCard(Map<String, dynamic> bookmark, bool isLandscape) {
    final surahNum = bookmark['surah'] as int;
    final verseNum = bookmark['verse'] as int;
    final isArabic = _currentLanguage == AppLanguage.arabic;

    // Find surah name
    String surahName = 'Surah $surahNum';
    if (_surahs.isNotEmpty) {
      final surah = _surahs.firstWhere(
        (s) => s['number'] == surahNum,
        orElse: () => null,
      );
      if (surah != null) {
        surahName = isArabic ? surah['name'] : surah['englishName'];
      }
    }

    // Calculate display verse number (adjust for Al-Fatiha)
    int displayVerseNum = verseNum;
    if (surahNum == 1 && verseNum > 1) {
      displayVerseNum = verseNum - 1;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () => _navigateToSurah(surahNum, numberInSurah: verseNum),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: isLandscape ? 200 : 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD700).withOpacity(0.15),
                const Color(0xFFFFD700).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark,
                  color: Color(0xFFFFD700),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      surahName,
                      style: GoogleFonts.amiri(
                        color: Colors.white,
                        fontSize: isLandscape ? 14 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isArabic
                          ? '$displayVerseNum آية'
                          : (_currentLanguage == AppLanguage.french
                                ? 'Verset $displayVerseNum'
                                : 'Ayah $displayVerseNum'),
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the continue reading banner using auto-saved position
  Widget _buildContinueReadingBanner(bool isLandscape) {
    final surahNum = _lastReadPosition!['surah'] as int;
    final verseNum = _lastReadPosition!['verse'] as int;
    final isArabic = _currentLanguage == AppLanguage.arabic;

    // Find surah name
    String surahName = 'Surah $surahNum';
    if (_surahs.isNotEmpty) {
      final surah = _surahs.firstWhere(
        (s) => s['number'] == surahNum,
        orElse: () => null,
      );
      if (surah != null) {
        surahName = isArabic ? surah['name'] : surah['englishName'];
      }
    }

    // Calculate display verse number (adjust for Al-Fatiha)
    int displayVerseNum = verseNum;
    if (surahNum == 1 && verseNum > 1) {
      displayVerseNum = verseNum - 1;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        _bookmarks.isNotEmpty ? 5 : (isLandscape ? 5 : 10),
        20,
        isLandscape ? 5 : 10,
      ),
      child: InkWell(
        onTap: () => _navigateToSurah(surahNum, numberInSurah: verseNum),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.15),
                const Color(0xFF4CAF50).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'مواصلة القراءة'
                          : (_currentLanguage == AppLanguage.french
                                ? 'Continuer la lecture'
                                : 'Continue Reading'),
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? '$surahName • $displayVerseNum آية'
                          : (_currentLanguage == AppLanguage.french
                                ? '$surahName • Verset $displayVerseNum'
                                : '$surahName • Ayah $displayVerseNum'),
                      style: GoogleFonts.amiri(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF4CAF50),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurahList() {
    if (_filteredSurahs.isEmpty) {
      return Center(
        child: Text(
          _currentLanguage == AppLanguage.arabic
              ? 'لا توجد نتائج'
              : 'No results found',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      cacheExtent: 1000, // Pre-render surah items for smoother browsing
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredSurahs.length,
      itemBuilder: (context, index) {
        final surah = _filteredSurahs[index];
        return _buildSurahItem(surah);
      },
    );
  }

  Widget _buildSurahItem(dynamic surah) {
    final int surahNumber = surah['number'];
    final bool isArabic = _currentLanguage == AppLanguage.arabic;
    final bool isFrench = _currentLanguage == AppLanguage.french;

    final String surahName = isArabic ? surah['name'] : surah['englishName'];
    final int ayahsCount = surah['numberOfAyahs'];

    String ayahsText;
    if (isArabic) {
      // Arabic pluralization rules: 3-10 use 'Ayat', 11+ use 'Aya'
      if (ayahsCount >= 3 && ayahsCount <= 10) {
        ayahsText = '$ayahsCount آيات';
      } else {
        ayahsText = '$ayahsCount آية';
      }
    } else if (isFrench) {
      ayahsText = '$ayahsCount Versets';
    } else {
      ayahsText = '$ayahsCount Verses';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: InkWell(
        onTap: () => _navigateToSurah(surahNumber),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            // ARABICS Mode: Number Left, Name Right (ltr row to put number first on left)
            // ENGLISH/FRENCH: Name Left, Number Right (rtl row to put number first on right)
            textDirection: isArabic ? TextDirection.ltr : TextDirection.rtl,
            children: [
              // Surah Number
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$surahNumber',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const Spacer(),

              // Surah Content
              Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                     surahName,
                     style: GoogleFonts.amiri(
                       color: Colors.white,
                       fontSize: 22,
                       fontWeight: FontWeight.bold,
                       height: 1.2,
                     ),
                     textAlign: isArabic ? TextAlign.right : TextAlign.left,
                   ),
                   const SizedBox(height: 2),
                   Text(
                     ayahsText,
                     style: GoogleFonts.outfit(
                       color: Colors.white.withOpacity(0.5),
                       fontSize: 13,
                       fontWeight: FontWeight.w400,
                     ),
                     textAlign: isArabic ? TextAlign.right : TextAlign.left,
                     textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                   ),
                 ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
