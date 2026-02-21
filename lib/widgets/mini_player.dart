import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../screens/verse_detail_screen.dart';

class MiniPlayer extends StatefulWidget {
  final AudioService audioService;
  final AppLanguage language;

  const MiniPlayer({
    super.key,
    required this.audioService,
    required this.language,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  void initState() {
    super.initState();
    widget.audioService.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    widget.audioService.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _getAyahLabel(int number) {
    switch (widget.language) {
      case AppLanguage.arabic:
        return 'آية';
      case AppLanguage.english:
        return 'Ayah';
      case AppLanguage.french:
        return 'Verset';
    }
  }

  String _getRecitingLabel() {
    switch (widget.language) {
      case AppLanguage.arabic:
        return 'تلاوة';
      case AppLanguage.english:
        return 'Reciting';
      case AppLanguage.french:
        return 'Récitation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = widget.audioService;

    // Only show if we have a valid ayah index and surah
    if (audioService.currentAyahIndex == null ||
        audioService.currentSurahNumber == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        // Navigate back to the verse detail screen
        if (audioService.currentSurahNumber != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerseDetailScreen(
                surahNumber: audioService.currentSurahNumber!,
                numberInSurah: audioService.currentAyahIndex != null
                    ? audioService.currentAyahIndex! + 1
                    : null,
                language: widget.language,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A237E).withOpacity(0.95),
              const Color(0xFF0D1642).withOpacity(0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator showing current ayah position
            if (audioService.currentVerses.isNotEmpty &&
                audioService.currentAyahIndex != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value:
                      (audioService.currentAyahIndex! + 1) /
                      audioService.currentVerses.length,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFFFFD700).withOpacity(0.8),
                  ),
                  minHeight: 3,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Album art / Quran icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFD700).withOpacity(0.3),
                        const Color(0xFFFFD700).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFFFFD700),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        audioService.currentSurahNames[widget.language] ??
                        audioService.currentSurahNames[AppLanguage.arabic] ??
                        _getRecitingLabel(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          String ayahText = '';
                          if (audioService.currentAyahIndex != null &&
                              audioService.currentVerses.isNotEmpty &&
                              audioService.currentAyahIndex! <
                                  audioService.currentVerses.length) {
                            final verse = audioService
                                .currentVerses[audioService.currentAyahIndex!];
                            final numberInSurah =
                                verse['numberInSurah'] as int? ??
                                (audioService.currentAyahIndex! + 1);
                            final ayahLabel = _getAyahLabel(numberInSurah);
                            ayahText =
                                '$ayahLabel $numberInSurah • ${audioService.currentReciter.getDisplayName(widget.language)}';
                          }
                          return Text(
                            ayahText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Controls - Only Play/Pause and Stop
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Play/Pause button
                    GestureDetector(
                      onTap: () => audioService.togglePlayPause(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFD700), Color(0xFFFFB800)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          audioService.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF0D1642),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stop button
                    GestureDetector(
                      onTap: () => audioService.stop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.stop_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
