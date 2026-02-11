import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/verse_detail_screen.dart';
import 'services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkAppState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    NotificationService.notificationTapped.listen((verseNumber) async {
      if (kDebugMode) {
        print('Notification tap received in AppEntryPoint: $verseNumber');
      }
      if (mounted) {
        // When notification is tapped, show HomeScreen with the notification verse
        setState(() {
          _showOnboarding = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkAppState() async {
    final notificationVerse = await _notificationService.getNotificationVerse();
    final isComplete = await _notificationService.isOnboardingComplete();

    if (mounted) {
      setState(() {
        // If there's a notification verse, show HomeScreen (it will display the verse)
        // Otherwise, check if onboarding is complete
        _showOnboarding = notificationVerse == null && !isComplete;
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

    return _showOnboarding ? const OnboardingScreen() : const HomeScreen();
  }
}
