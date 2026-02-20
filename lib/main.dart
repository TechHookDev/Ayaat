import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/update_splash_screen.dart';
import 'screens/verse_detail_screen.dart';
import 'services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  runApp(const AyaatApp());
}

class AyaatApp extends StatelessWidget {
  const AyaatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ayaat - آيات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.amiriTextTheme(Theme.of(context).textTheme),
      ),
      home: const AppEntryPoint(),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  bool _showOnboarding = true;
  bool _showUpdateSplash = false;
  int? _targetVerseNumber;

  @override
  void initState() {
    super.initState();
    _checkAppState();
    _setupNotificationListener();
    // Use delay on startup to allow UI to render first
    _notificationService.rescheduleNotifications(useDelay: true);
    // Check for travel updates (smart location check)
    _notificationService.checkLocationAndUpdate();
  }

  void _setupNotificationListener() {
    NotificationService.notificationTapped.listen((verseNumber) async {
      if (kDebugMode) {
        print('Notification tap received in AppEntryPoint: $verseNumber');
      }
      if (mounted) {
        // When notification is tapped, show HomeScreen with the notification verse
        setState(() {
          _targetVerseNumber = verseNumber;
          _showOnboarding = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkAppState() async {
    // Check if app was launched from notification
    final launchVerseNumber = await _notificationService.getLaunchVerseNumber();
    if (launchVerseNumber != null) {
      if (mounted) {
        setState(() {
          _targetVerseNumber = launchVerseNumber;
          _showOnboarding = false;
          _isLoading = false;
        });
      }
      return;
    }

    final notificationVerse = await _notificationService.getNotificationVerse();
    final isComplete = await _notificationService.isOnboardingComplete();

    bool showSplash = false;
    if (notificationVerse == null) {
      final prefs = await SharedPreferences.getInstance();
      showSplash = !(prefs.getBool('has_seen_v109_splash') ?? false);
    }

    if (mounted) {
      setState(() {
        // If there's a notification verse, show HomeScreen (it will display the verse)
        // Otherwise, check if onboarding is complete
        _showOnboarding = notificationVerse == null && !isComplete;
        _showUpdateSplash = showSplash;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return const OnboardingScreen();
    }
    
    if (_showUpdateSplash && _targetVerseNumber == null) {
      return const UpdateSplashScreen();
    }
    
    return HomeScreen(initialVerseNumber: _targetVerseNumber);
  }
}
