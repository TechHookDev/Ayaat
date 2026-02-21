import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/reciter.dart';
import '../services/language_service.dart';

/// Main audio service for Quran recitation with background playback
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isInitialized = false;
  Reciter _currentReciter = Reciters.getDefault();
  bool _isPlayingNext = false; // Flag to prevent duplicate next calls

  // Playback state
  bool _isPlaying = false;
  bool _isContinuousMode = false;
  int? _currentSurahNumber;
  int? _currentAyahIndex;
  int? _currentGlobalAyahNumber;
  Map<AppLanguage, String> _currentSurahNames = {};
  List<Map<String, dynamic>> _currentVerses = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isContinuousMode => _isContinuousMode;
  int? get currentSurahNumber => _currentSurahNumber;
  int? get currentAyahIndex => _currentAyahIndex;
  int? get currentGlobalAyahNumber => _currentGlobalAyahNumber;
  Map<AppLanguage, String> get currentSurahNames => _currentSurahNames;
  List<Map<String, dynamic>> get currentVerses => _currentVerses;
  Reciter get currentReciter => _currentReciter;
  bool get hasActivePlayback => _isPlaying || _currentAyahIndex != null;

  // Streams
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Cancel any existing subscription before creating a new one
    await _playerStateSubscription?.cancel();

    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      debugPrint('🎵 Player State: ${state.processingState}, Playing: ${state.playing}');
      _isPlaying = state.playing;
      notifyListeners();
    });

    // Listen to index changes to update UI tracking
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _audioPlayer.audioSource is ConcatenatingAudioSource) {
        final playlist = _audioPlayer.audioSource as ConcatenatingAudioSource;
        if (index < playlist.length) {
          final source = playlist.children[index];
          if (source is UriAudioSource && source.tag is MediaItem) {
            final mediaItem = source.tag as MediaItem;
            
            // Skip UI updates for Bismillah
            if (mediaItem.extras?['isBismillah'] == true) {
              debugPrint('🕋 Bismillah playing...');
              return;
            }

            final actualIndex = mediaItem.extras?['index'] as int?;
            if (actualIndex != null) {
              _currentAyahIndex = actualIndex;
              _currentGlobalAyahNumber = int.tryParse(mediaItem.id);
              debugPrint('🆕 Playlist Index Changed: $index -> Verse Index: $actualIndex');
              notifyListeners();
            }
          }
        }
      }
    });

    _isInitialized = true;
  }

  void setReciter(Reciter reciter) {
    _currentReciter = reciter;
    notifyListeners();
  }

  Future<void> playAyah({
    required int globalAyahNumber,
    required int surahNumber,
    required int ayahIndex,
    required Map<AppLanguage, String> surahNames,
    required List<Map<String, dynamic>> verses,
    bool continuousMode = true,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      _currentSurahNumber = surahNumber;
      _currentAyahIndex = ayahIndex;
      _currentGlobalAyahNumber = globalAyahNumber;
      _currentSurahNames = surahNames;
      _currentVerses = verses;
      _isPlayingNext = false;

      final language = await LanguageService().getCurrentLanguage();
      final reciterName = _currentReciter.getDisplayName(language);
      final surahName = surahNames[language] ?? surahNames[AppLanguage.arabic] ?? '';

      if (continuousMode) {
        // Create a playlist from this ayah to the end of the surah
        final playlist = ConcatenatingAudioSource(children: []);
        
        // Add Bismillah if starting in the middle, except for Surah 9 (Tawbah)
        // and Surah 1 (Fatiha - if starting at 0, we already show Bismillah in UI)
        if (ayahIndex > 0 && surahNumber != 9) {
          final bismillahUrl = _currentReciter.getAudioUrl(1, 1); // 001001.mp3
          playlist.add(
            AudioSource.uri(
              Uri.parse(bismillahUrl),
            tag: MediaItem(
              id: 'bismillah',
              title: language == AppLanguage.arabic 
                  ? 'آيات • سورة $surahName' 
                  : 'Ayaat Quran • Surah $surahName',
              artist: language == AppLanguage.arabic 
                  ? 'البسملة • $reciterName' 
                  : 'Bismillah • $reciterName',
              album: 'Ayaat - آيات',
              artUri: Uri.parse('https://raw.githubusercontent.com/TechHookDev/Ayaat/main/assets/icon_512.png'),
              displayTitle: language == AppLanguage.arabic 
                  ? 'آيات • سورة $surahName' 
                  : 'Ayaat Quran • Surah $surahName',
              displaySubtitle: language == AppLanguage.arabic 
                  ? 'البسملة • $reciterName' 
                  : 'Bismillah • $reciterName',
              extras: {'isBismillah': true},
            ),
          ),
          );
          debugPrint('🕌 Prepended Bismillah to playlist');
        }

        for (int i = ayahIndex; i < verses.length; i++) {
          final verse = verses[i];
          final gNum = verse['number'] as int;
          final sNum = surahNumber;
          final iNum = verse['numberInSurah'] as int;
          final url = _currentReciter.getAudioUrl(sNum, iNum);
          
          playlist.add(
            AudioSource.uri(
              Uri.parse(url),
              tag: MediaItem(
                id: gNum.toString(),
                title: language == AppLanguage.arabic 
                    ? 'آيات • سورة $surahName' 
                    : 'Ayaat Quran • Surah $surahName',
                artist: language == AppLanguage.arabic 
                    ? 'آية $iNum • $reciterName'
                    : language == AppLanguage.french
                        ? 'Verset $iNum • $reciterName'
                        : 'Ayah $iNum • $reciterName',
                album: 'Ayaat - آيات',
                artUri: Uri.parse('https://raw.githubusercontent.com/TechHookDev/Ayaat/main/assets/icon_512.png'),
                displayTitle: language == AppLanguage.arabic 
                    ? 'آيات • سورة $surahName' 
                    : 'Ayaat • Surah $surahName',
                displaySubtitle: language == AppLanguage.arabic 
                    ? 'آية $iNum • $reciterName'
                    : language == AppLanguage.french
                        ? 'Verset $iNum • $reciterName'
                        : 'Ayah $iNum • $reciterName',
                extras: {'index': i},
              ),
            ),
          );
        }

        debugPrint('🎼 Setting Playlist with ${playlist.length} verses');
        await _audioPlayer.setAudioSource(playlist);
      } else {
        // Single ayah mode
        final numberInSurah = verses[ayahIndex]['numberInSurah'] as int;
        final url = _currentReciter.getAudioUrl(surahNumber, numberInSurah);
        
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            tag: MediaItem(
              id: globalAyahNumber.toString(),
              title: language == AppLanguage.arabic 
                  ? 'آيات • سورة $surahName' 
                  : 'Ayaat Quran • Surah $surahName',
              artist: language == AppLanguage.arabic 
                  ? 'آية $numberInSurah • $reciterName'
                  : language == AppLanguage.french
                      ? 'Verset $numberInSurah • $reciterName'
                      : 'Ayah $numberInSurah • $reciterName',
              album: 'Ayaat - آيات',
              artUri: Uri.parse('https://raw.githubusercontent.com/TechHookDev/Ayaat/main/assets/icon_512.png'),
              displayTitle: language == AppLanguage.arabic 
                  ? 'آيات • سورة $surahName' 
                  : 'Ayaat • Surah $surahName',
              displaySubtitle: language == AppLanguage.arabic 
                  ? 'آية $numberInSurah • $reciterName'
                  : language == AppLanguage.french
                      ? 'Verset $numberInSurah • $reciterName'
                      : 'Ayah $numberInSurah • $reciterName',
              extras: {'index': ayahIndex},
            ),
          ),
        );
      }

      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
    }
  }



  Future<void> playSurah({
    required int surahNumber,
    required Map<AppLanguage, String> surahNames,
    required List<Map<String, dynamic>> verses,
  }) async {
    if (verses.isEmpty) return;

    _currentVerses = verses;
    _currentSurahNumber = surahNumber;
    _currentSurahNames = surahNames;
    _isContinuousMode = true;
    _isPlayingNext = false;

    final firstVerse = verses[0];
    final globalNumber = firstVerse['number'] as int;

    await playAyah(
      globalAyahNumber: globalNumber,
      surahNumber: surahNumber,
      ayahIndex: 0,
      surahNames: surahNames,
      verses: verses,
      continuousMode: true,
    );
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else if (_currentGlobalAyahNumber != null) {
      await _audioPlayer.play();
    }
  }

  Future<void> play() async {
    if (_currentGlobalAyahNumber != null) {
      await _audioPlayer.play();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isContinuousMode = false;
    _isPlayingNext = false;
    _currentAyahIndex = null;
    _currentGlobalAyahNumber = null;
    notifyListeners();
  }

  Future<void> seekToNext() async {
    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
    }
  }

  Future<void> seekToPrevious() async {
    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
    }
  }

  Future<void> seekToAyah(int index) async {
    if (index >= 0 && index < _currentVerses.length) {
      final verse = _currentVerses[index];
      final globalNumber = verse['number'] as int;

      await playAyah(
        globalAyahNumber: globalNumber,
        surahNumber: _currentSurahNumber!,
        ayahIndex: index,
        surahNames: _currentSurahNames,
        verses: _currentVerses,
        continuousMode: _isContinuousMode,
      );
    }
  }

  Future<void> disposeService() async {
    await _playerStateSubscription?.cancel();
    await _audioPlayer.dispose();
  }
}
