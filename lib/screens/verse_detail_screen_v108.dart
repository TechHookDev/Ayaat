import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/language_service.dart';

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
  String _surahName = '';
  bool _isLoading = true;
  String? _error;
  int? _targetVerseIndex;
  final Map<int, GlobalKey> _verseKeys = {};

  @override
  void initState() {
    super.initState();
    _loadSurah();
  }

  @override
  void dispose() {
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

        // Get surah name in the correct language
        _surahName = _getSurahName(surahData);

        _verses = verses
            .map<Map<String, dynamic>>(
              (v) => {
                'numberInSurah': v['numberInSurah'] as int,
                'text': v['text'] as String,
              },
            )
            .toList();

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
          _isLoading = false;
        });

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
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
    if (!_scrollController.hasClients) {
      debugPrint('✗ ScrollController not ready');
      return;
    }

    final key = _verseKeys[verseIndex];
    if (key == null) {
      debugPrint('✗ No key for verse index $verseIndex');
      return;
    }

    final context = key.currentContext;
    if (context == null) {
      debugPrint('✗ Widget not found for verse index $verseIndex');
      return;
    }

    // Use ensureVisible for precise scrolling
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      alignment: 0.3, // 30% from top
    );

    debugPrint('✓ Successfully scrolled to verse ${widget.numberInSurah}');
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
              if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      style: GoogleFonts.amiri(fontSize: 16, color: Colors.red),
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
            ],
          ),
        ),
      ),
    );
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
          const SizedBox(width: 48), // Balance with back button
        ],
      ),
    );
  }

  Widget _buildVersesList() {
    // Use SingleChildScrollView with Column for 100% reliability
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Bismillah header (except Surah 9)
          if (widget.surahNumber != 9) _buildBismillah(),
          // All verses
          ..._verses.asMap().entries.map((entry) {
            return _buildVerseItem(entry.key, entry.value);
          }),
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

    String text = verse['text'];

    // Remove bismillah from first verse (except Surah 1)
    if (verseIndex == 0 &&
        widget.surahNumber != 1 &&
        widget.surahNumber != 9 &&
        widget.language == AppLanguage.arabic) {
      text = _removeBismillah(text);
    }

    final goldColor = const Color(0xFFFFD700);
    final textColor = isTarget ? goldColor : Colors.white;
    final numberColor = isTarget ? goldColor : Colors.white54;

    return Column(
      key: isTarget ? _verseKeys[verseIndex] : null,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: widget.language == AppLanguage.arabic
              ? GoogleFonts.amiri(fontSize: 24, color: textColor, height: 1.8)
              : GoogleFonts.outfit(fontSize: 18, color: textColor, height: 1.6),
          textAlign: TextAlign.center,
          textDirection: widget.language == AppLanguage.arabic
              ? TextDirection.rtl
              : TextDirection.ltr,
        ),
        const SizedBox(height: 8),
        Text(
          '$verseNumber',
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
