import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/quran_api.dart';
import '../services/language_service.dart';
import '../services/preferences_service.dart';
import 'verse_detail_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  final QuranApiService _apiService = QuranApiService();
  final LanguageService _languageService = LanguageService();
  final PreferencesService _prefs = PreferencesService();
  
  List<dynamic> _surahs = [];
  List<dynamic> _filteredSurahs = [];
  bool _isLoading = true;
  String? _error;
  AppLanguage _currentLanguage = AppLanguage.arabic;
  String _searchQuery = '';
  Map<String, int>? _bookmark;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final lang = await _languageService.getCurrentLanguage();
      final bookmark = await _prefs.getBookmark();
      
      setState(() => _currentLanguage = lang);
      
      final surahs = await _apiService.getSurahs(lang);
      if (mounted) {
        setState(() {
          _surahs = surahs;
          _filteredSurahs = surahs;
          _bookmark = bookmark;
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
          final translationName = surah['englishNameTranslation'].toString().toLowerCase();
          
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
    // Refresh bookmark when returning
    final bookmark = await _prefs.getBookmark();
    if (mounted) {
      setState(() {
        _bookmark = bookmark;
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
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              if (_bookmark != null && _searchQuery.isEmpty) _buildContinueReadingBanner(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : _buildSurahList(),
              ),
            ],
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
        return 'Rechercher une sourate...';
      case AppLanguage.english:
        return 'Search Surah...';
      case AppLanguage.arabic:
      default:
        return 'ابحث عن سورة...';
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          ),
          Expanded(
            child: Text(
              _getHeaderTitle(),
              style: GoogleFonts.amiri(
                fontSize: 28,
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: TextField(
          onChanged: _filterSurahs,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            hintText: _getSearchHint(),
            hintStyle: GoogleFonts.outfit(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
          textDirection: _currentLanguage == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr,
        ),
      ),
    );
  }

  Widget _buildContinueReadingBanner() {
    if (_bookmark == null) return const SizedBox.shrink();
    
    final surahNum = _bookmark!['surah']!;
    final verseNum = _bookmark!['verse']!;
    final isArabic = _currentLanguage == AppLanguage.arabic;
    
    // Find surah name if we have loaded surahs
    String surahName = 'Surah $surahNum';
    if (_surahs.isNotEmpty) {
      final surah = _surahs.firstWhere((s) => s['number'] == surahNum, orElse: () => null);
      if (surah != null) {
        surahName = isArabic ? surah['name'] : surah['englishName'];
      }
    }

    String text;
    if (_currentLanguage == AppLanguage.french) {
      text = 'Continuer de lire: $surahName, verset $verseNum';
    } else if (_currentLanguage == AppLanguage.english) {
      text = 'Continue reading: $surahName, Verse $verseNum';
    } else {
      text = 'استمر في القراءة: $surahName، آية $verseNum';
    }

    int displayVerseNum = verseNum;
    if (surahNum == 1 && verseNum > 1) {
      displayVerseNum = verseNum - 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 10),
      child: InkWell(
        onTap: () => _navigateToSurah(surahNum, numberInSurah: verseNum),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD700).withOpacity(0.15),
                const Color(0xFFFFD700).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bookmark, color: Color(0xFFFFD700), size: 20),
              ),
              const SizedBox(width: 16),
               Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentLanguage == AppLanguage.arabic ? 'متابعة القراءة' : 'Continue Reading',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$surahName • Ayah $displayVerseNum',
                      style: GoogleFonts.amiri(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD700), size: 16),
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
          _currentLanguage == AppLanguage.arabic ? 'لا توجد نتائج' : 'No results found',
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
      ayahsText = '$ayahsCount آية';
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
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
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
                crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
