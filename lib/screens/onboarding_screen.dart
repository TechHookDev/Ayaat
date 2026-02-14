import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final NotificationService _notificationService = NotificationService();
  final LanguageService _languageService = LanguageService();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Onboarding data
  AppLanguage _selectedLanguage = AppLanguage.arabic;
  bool _wantsNotifications = true;
  bool _usePrayerTimes = true;
  int _notificationCount = 1;
  final List<TimeOfDay> _notificationTimes = [];
  bool _isLoadingLocation = false;
  String? _locationError;
  
  // For animated "Next" button on first page
  Timer? _nextButtonTimer;
  String _animatedNextLabel = 'التالي';
  int _animatedLabelIndex = 0;
  final List<String> _nextLabels = ['التالي', 'Next', 'Suivant'];

  @override
  void initState() {
    super.initState();
    _startNextButtonAnimation();
  }

  void _startNextButtonAnimation() {
    _nextButtonTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPage == 0) {
        setState(() {
          _animatedLabelIndex = (_animatedLabelIndex + 1) % _nextLabels.length;
          _animatedNextLabel = _nextLabels[_animatedLabelIndex];
        });
      }
    });
  }

  @override
  void dispose() {
    _nextButtonTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    // Page 0: Welcome -> Page 1: Language
    // Page 1: Language -> Page 2: Notifications
    // Page 2: Notifications -> Page 3: Prayer Times Selection
    // Page 3: Prayer Times Selection -> Page 4: Confirmation (if prayer times) or Page 5: Manual
    // Page 4: Confirmation -> Finish
    // Page 5: Manual -> Finish

    // If user is on notification preference page (page 2) and wants notifications
    if (_currentPage == 2 && _wantsNotifications) {
      // Request notification permission before going to next page
      await _notificationService.requestPermissions();
    }

    // Skip prayer times pages if user doesn't want notifications
    if (_currentPage == 2 && !_wantsNotifications) {
      _finishOnboarding();
      return;
    }

    // On Prayer Times Selection page (page 3)
    if (_currentPage == 3) {
      if (_usePrayerTimes) {
        // Request location and calculate prayer times
        bool success = await _requestLocationAndCalculatePrayerTimes();
        if (success) {
          // Go to confirmation page (page 4)
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        return; // Don't proceed if failed or already navigating
      } else {
        // Manual setup - go directly to manual page (page 5)
        _pageController.animateToPage(
          5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return;
      }
    }

    // On confirmation page (page 4 with prayer times) or manual page (page 5), finish
    if ((_currentPage == 4 && _usePrayerTimes) || _currentPage == 5) {
      _finishOnboarding();
      return;
    }

    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<bool> _requestLocationAndCalculatePrayerTimes() async {
    print('🔴 REQUESTING LOCATION AND CALCULATING PRAYER TIMES...');

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      print('🔴 Checking location service...');
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('🔴 Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        setState(() {
          _locationError = _getLocationDisabledText();
          _isLoadingLocation = false;
        });
        return false;
      }

      print('🔴 Checking location permission...');
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print('🔴 Current permission: $permission');

      if (permission == LocationPermission.denied) {
        print('🔴 Requesting permission...');
        permission = await Geolocator.requestPermission();
        print('🔴 After request permission: $permission');

        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = _getLocationDeniedText();
            _isLoadingLocation = false;
          });
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = _getLocationDeniedForeverText();
          _isLoadingLocation = false;
        });
        return false;
      }

      print('🔴 Getting current position...');
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print(
        '🔴 Position obtained: ${position.latitude}, ${position.longitude}',
      );

      print('🔴 Calculating prayer times...');
      // Calculate prayer times with position
      await _calculatePrayerTimes(position.latitude, position.longitude);
      print('🔴 Prayer times calculated: $_notificationTimes');

      setState(() {
        _isLoadingLocation = false;
        _usePrayerTimes = true;
      });

      print('🔴 Success! Ready to navigate to confirmation page...');
      return true;
    } catch (e, stackTrace) {
      print('🔴 ERROR: $e');
      print('🔴 STACK TRACE: $stackTrace');
      setState(() {
        _locationError = '${_getLocationErrorText()}\nError: $e';
        _isLoadingLocation = false;
      });
      return false;
    }
  }

  Future<void> _calculatePrayerTimes(double latitude, double longitude) async {
    final coordinates = Coordinates(latitude, longitude);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.shafi;

    final prayerTimes = PrayerTimes.today(coordinates, params);

    // Add 30 minutes to each prayer time for notifications
    setState(() {
      _notificationTimes.clear();

      // Fajr + 30 min
      final fajr = prayerTimes.fajr.add(const Duration(minutes: 30));
      _notificationTimes.add(TimeOfDay(hour: fajr.hour, minute: fajr.minute));

      // Dhuhr + 30 min
      final dhuhr = prayerTimes.dhuhr.add(const Duration(minutes: 30));
      _notificationTimes.add(TimeOfDay(hour: dhuhr.hour, minute: dhuhr.minute));

      // Asr + 30 min
      final asr = prayerTimes.asr.add(const Duration(minutes: 30));
      _notificationTimes.add(TimeOfDay(hour: asr.hour, minute: asr.minute));

      // Maghrib + 30 min
      final maghrib = prayerTimes.maghrib.add(const Duration(minutes: 30));
      _notificationTimes.add(
        TimeOfDay(hour: maghrib.hour, minute: maghrib.minute),
      );

      // Isha + 30 min
      final isha = prayerTimes.isha.add(const Duration(minutes: 30));
      _notificationTimes.add(TimeOfDay(hour: isha.hour, minute: isha.minute));

      _notificationCount = _notificationTimes.length;
    });
  }

  Future<void> _calculateAndSetPrayerTimes() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _calculatePrayerTimes(position.latitude, position.longitude);
    } catch (e) {
      // Fallback to default times if location fails
    }
  }

  Future<void> _finishOnboarding() async {
    // Save language preference
    await _languageService.setLanguage(_selectedLanguage);

    // Save notification preferences
    if (_wantsNotifications && _notificationTimes.isNotEmpty) {
      // Save notification mode explicitly
      await _notificationService.setNotificationMode(
        _usePrayerTimes ? 'prayer' : 'manual',
      );
      await _notificationService.scheduleMultipleDaily(_notificationTimes);
    } else {
      await _notificationService.cancelAll();
    }

    // Mark onboarding as complete
    await _notificationService.setOnboardingComplete(true);

    // Clear notification verse so app starts on home screen, not verse detail
    await _notificationService.clearNotificationVerse();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _updateNotificationCount(int count) {
    setState(() {
      _notificationCount = count;
      // Adjust times list
      while (_notificationTimes.length < count) {
        // Add default times (9am, 12pm, 6pm, 9pm)
        final defaultHours = [9, 12, 18, 21];
        final hour =
            defaultHours[_notificationTimes.length % defaultHours.length];
        _notificationTimes.add(TimeOfDay(hour: hour, minute: 0));
      }
      while (_notificationTimes.length > count) {
        _notificationTimes.removeLast();
      }
    });
  }

  Future<void> _selectTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTimes[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              onPrimary: Color(0xFF0D1B2A),
              surface: Color(0xFF1A237E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _notificationTimes[index] = picked;
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
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildLanguageSelectionPage(),
                    _buildNotificationPreferencePage(),
                    _buildPrayerTimesSelectionPage(),
                    _buildPrayerTimesConfirmationPage(),
                    _buildTimeSelectionPage(),
                  ],
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
            ),
            child: const Icon(
              Icons.menu_book,
              size: 60,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'آيات',
            style: GoogleFonts.amiri(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ayaat',
            style: GoogleFonts.outfit(
              fontSize: 24,
              color: Colors.white70,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'تطبيق آيات يقدم لك آيات عشوائية من القرآن الكريم مع إمكانية التنبيهات اليومية',
            style: GoogleFonts.amiri(
              fontSize: 18,
              color: Colors.white70,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          Text(
            'Daily Quran verses with optional daily reminders',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Versets quotidiens du Coran avec rappels facultatifs',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.language, size: 60, color: Color(0xFFFFD700)),
          const SizedBox(height: 30),
          Text(
            'اختر اللغة',
            style: GoogleFonts.amiri(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose Language / Choisissez la langue',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 40),
          _buildLanguageOption(AppLanguage.arabic, 'العربية', 'Arabic'),
          const SizedBox(height: 16),
          _buildLanguageOption(AppLanguage.english, 'English', 'الإنجليزية'),
          const SizedBox(height: 16),
          _buildLanguageOption(AppLanguage.french, 'Français', 'الفرنسية'),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    AppLanguage language,
    String name,
    String subtitle,
  ) {
    final isSelected = _selectedLanguage == language;
    return InkWell(
      onTap: () => setState(() => _selectedLanguage = language),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD700).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFFD700) : Colors.white54,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPreferencePage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _wantsNotifications
                ? Icons.notifications_active
                : Icons.notifications_off,
            size: 80,
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 40),
          Text(
            _getNotificationTitle(),
            style: GoogleFonts.amiri(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getNotificationSubtitle(),
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  _getNotificationDescription(),
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: _selectedLanguage == AppLanguage.arabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChoiceButton(
                      label: _getNoText(),
                      isSelected: !_wantsNotifications,
                      onTap: () => setState(() => _wantsNotifications = false),
                    ),
                    const SizedBox(width: 20),
                    _buildChoiceButton(
                      label: _getYesText(),
                      isSelected: _wantsNotifications,
                      onTap: () => setState(() => _wantsNotifications = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesSelectionPage() {
    if (!_wantsNotifications) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 80, color: Color(0xFFFFD700)),
          const SizedBox(height: 30),
          Text(
            _getPrayerTimesTitle(),
            style: GoogleFonts.amiri(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  _getPrayerTimesDescription(),
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: _selectedLanguage == AppLanguage.arabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
                if (_locationError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _locationError!,
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 30),
                _buildChoiceButton(
                  label: _getUsePrayerTimesText(),
                  isSelected: _usePrayerTimes,
                  onTap: () {
                    print('🔴 SELECTED: Use Prayer Times');
                    setState(() => _usePrayerTimes = true);
                  },
                ),
                const SizedBox(height: 12),
                _buildChoiceButton(
                  label: _getManualSetupText(),
                  isSelected: !_usePrayerTimes,
                  onTap: () {
                    print('🔴 SELECTED: Manual Setup');
                    setState(() {
                      _usePrayerTimes = false;
                      // Set default 9am time for manual setup and update count
                      _notificationCount = 1;
                      _notificationTimes.clear();
                      _notificationTimes.add(
                        const TimeOfDay(hour: 9, minute: 0),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesConfirmationPage() {
    // Only show this page if user selected prayer times AND we have calculated times
    if (!_wantsNotifications ||
        !_usePrayerTimes ||
        _notificationTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Color(0xFFFFD700)),
            const SizedBox(height: 30),
            Text(
              _getConfirmationTitle(),
              style: GoogleFonts.amiri(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getConfirmationSubtitle(),
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    _getNotificationTimesLabel(),
                    style: GoogleFonts.amiri(
                      fontSize: 16,
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Show calculated times
                  ...List.generate(_notificationTimes.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD700)),
                        ),
                        child: Text(
                          _formatPrayerTime(_notificationTimes[index]),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Text(
                    _getConfirmationDescription(),
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: _selectedLanguage == AppLanguage.arabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ],
              ),
            ),
            // Removed Confirm button - Next button will handle this
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelectionPage() {
    if (!_wantsNotifications) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Color(0xFFFFD700)),
            const SizedBox(height: 40),
            Text(
              'تم الاختيار',
              style: GoogleFonts.amiri(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All Set',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 30),
            Text(
              'يمكنك تفعيل التنبيهات لاحقاً من الإعدادات',
              style: GoogleFonts.amiri(fontSize: 18, color: Colors.white70),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Text(
              'You can enable notifications later in settings',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.access_time, size: 60, color: Color(0xFFFFD700)),
          const SizedBox(height: 30),
          Text(
            _getNotificationTimesTitle(),
            style: GoogleFonts.amiri(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getNotificationTimesSubtitle(),
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Text(
            _getNotificationTimesDescription(),
            style: GoogleFonts.amiri(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
            textDirection: _selectedLanguage == AppLanguage.arabic
                ? TextDirection.rtl
                : TextDirection.ltr,
          ),
          const SizedBox(height: 16),
          // Notification count selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _notificationCount > 1
                      ? () => _updateNotificationCount(_notificationCount - 1)
                      : null,
                  icon: Icon(
                    Icons.remove,
                    color: _notificationCount > 1
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$_notificationCount',
                    style: GoogleFonts.amiri(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _notificationCount < 5
                      ? () => _updateNotificationCount(_notificationCount + 1)
                      : null,
                  icon: Icon(
                    Icons.add,
                    color: _notificationCount < 5
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Time selection for each notification
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTimesLabel(),
                    style: GoogleFonts.amiri(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFD700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _notificationTimes.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.white24, height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.2),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.amiri(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFD700),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            '${_getNotificationText()} ${index + 1}',
                            style: GoogleFonts.amiri(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            textDirection: _selectedLanguage == AppLanguage.arabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                          trailing: InkWell(
                            onTap: () => _selectTime(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFD700),
                                ),
                              ),
                              child: Text(
                                _formatTime(_notificationTimes[index]),
                                style: GoogleFonts.amiri(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFD700),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD700)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.amiri(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0D1B2A) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    // Determine button text based on current page
    String buttonText;
    if (_currentPage == 4 && _usePrayerTimes) {
      buttonText = _getStartText(); // Confirmation page
    } else if (_currentPage == 5) {
      buttonText = _getStartText(); // Manual setup page
    } else {
      buttonText = _getNextText();
    }

    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicators (5 pages - manual setup shows as last page)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              // Map page index to dot index
              // Pages 0-3 map to dots 0-3
              // Page 4 (confirmation) and Page 5 (manual) both show dot 4
              int dotIndex = index;
              int activePage = _currentPage;
              if (_currentPage == 5) {
                activePage = 4; // Manual setup shows last dot
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: activePage == dotIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: activePage == dotIndex
                      ? const Color(0xFFFFD700)
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 30),
          // Back and Next/Finish buttons
          Row(
            children: [
              // Back button (hidden on first page)
              if (_currentPage > 0)
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage > 0) {
                          // If on manual setup page (5) and going back, skip confirmation page (4)
                          if (_currentPage == 5) {
                            _pageController.animateToPage(
                              3, // Go back to prayer times selection
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Icon(Icons.arrow_back),
                    ),
                  ),
                ),
              // Next/Finish button
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0D1B2A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _currentPage == 0 ? _animatedNextLabel : buttonText,
                      key: ValueKey(_currentPage == 0 ? _animatedNextLabel : buttonText),
                      style: GoogleFonts.amiri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'م' : 'ص';
    final hour12 = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    return '$hour12:$minute $period';
  }

  String _getNextText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'التالي';
      case AppLanguage.english:
        return 'Next';
      case AppLanguage.french:
        return 'Suivant';
    }
  }

  String _getStartText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'ابدأ';
      case AppLanguage.english:
        return 'Start';
      case AppLanguage.french:
        return 'Commencer';
    }
  }

  String _getYesText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'نعم';
      case AppLanguage.english:
        return 'Yes';
      case AppLanguage.french:
        return 'Oui';
    }
  }

  String _getNoText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'لا';
      case AppLanguage.english:
        return 'No';
      case AppLanguage.french:
        return 'Non';
    }
  }

  String _getLocationDisabledText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'خدمة الموقع غير مفعّلة';
      case AppLanguage.english:
        return 'Location service is disabled';
      case AppLanguage.french:
        return 'Le service de localisation est désactivé';
    }
  }

  String _getLocationDeniedText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'تم رفض إذن الموقع';
      case AppLanguage.english:
        return 'Location permission denied';
      case AppLanguage.french:
        return 'Permission de localisation refusée';
    }
  }

  String _getLocationDeniedForeverText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'يرجى تفعيل إذن الموقع من الإعدادات';
      case AppLanguage.english:
        return 'Please enable location permission from settings';
      case AppLanguage.french:
        return 'Veuillez activer la permission de localisation dans les paramètres';
    }
  }

  String _getLocationErrorText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'حدث خطأ في تحديد الموقع';
      case AppLanguage.english:
        return 'Error getting location';
      case AppLanguage.french:
        return 'Erreur lors de la localisation';
    }
  }

  String _getPrayerTimesTitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'أوقات الصلاة';
      case AppLanguage.english:
        return 'Prayer Times';
      case AppLanguage.french:
        return 'Heures de Prière';
    }
  }

  String _getPrayerTimesDescription() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'نود معرفة موقعك لتحديد أوقات التنبيهات بناءً على أوقات الصلاة في منطقتك (موعد الصلاة + 30 دقيقة)';
      case AppLanguage.english:
        return 'We would like to know your location to set notification times based on prayer times in your area (prayer time + 30 minutes)';
      case AppLanguage.french:
        return 'Nous aimerions connaître votre emplacement pour définir les heures de notification en fonction des heures de prière dans votre région (heure de prière + 30 minutes)';
    }
  }

  String _getUsePrayerTimesText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'استخدم أوقات الصلاة';
      case AppLanguage.english:
        return 'Use Prayer Times';
      case AppLanguage.french:
        return 'Utiliser les Heures de Prière';
    }
  }

  String _getManualSetupText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'إعداد يدوي';
      case AppLanguage.english:
        return 'Manual Setup';
      case AppLanguage.french:
        return 'Configuration Manuelle';
    }
  }

  String _getAllowLocationText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'السماح بالموقع';
      case AppLanguage.english:
        return 'Allow Location';
      case AppLanguage.french:
        return 'Autoriser la Localisation';
    }
  }

  String _getConfirmationTitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'تم حساب أوقات التنبيهات';
      case AppLanguage.english:
        return 'Notification Times Calculated';
      case AppLanguage.french:
        return 'Heures de Notification Calculées';
    }
  }

  String _getConfirmationSubtitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'بناءً على أوقات الصلاة في منطقتك';
      case AppLanguage.english:
        return 'Based on prayer times in your area';
      case AppLanguage.french:
        return 'Basé sur les heures de prière dans votre région';
    }
  }

  String _getNotificationTimesLabel() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'أوقات التنبيهات:';
      case AppLanguage.english:
        return 'Notification Times:';
      case AppLanguage.french:
        return 'Heures de Notification:';
    }
  }

  String _getConfirmationDescription() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'سيتم إرسال آية عشوائية من القرآن الكريم في هذه الأوقات';
      case AppLanguage.english:
        return 'You will receive a random Quran verse at these times';
      case AppLanguage.french:
        return 'Vous recevrez un verset du Coran aléatoire à ces heures';
    }
  }

  String _getConfirmText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'تأكيد';
      case AppLanguage.english:
        return 'Confirm';
      case AppLanguage.french:
        return 'Confirmer';
    }
  }

  String _getNotificationTitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'التنبيهات';
      case AppLanguage.english:
        return 'Notifications';
      case AppLanguage.french:
        return 'Notifications';
    }
  }

  String _getNotificationSubtitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'التنبيهات اليومية';
      case AppLanguage.english:
        return 'Daily Notifications';
      case AppLanguage.french:
        return 'Notifications quotidiennes';
    }
  }

  String _getNotificationDescription() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'هل تريد تلقي تنبيهات يومية بآيات من القرآن الكريم؟';
      case AppLanguage.english:
        return 'Would you like to receive daily Quran verse reminders?';
      case AppLanguage.french:
        return 'Souhaitez-vous recevoir des rappels quotidiens de versets du Coran ?';
    }
  }

  String _getNotificationTimesTitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'مواعيد التنبيهات';
      case AppLanguage.english:
        return 'Notification Times';
      case AppLanguage.french:
        return 'Heures de notification';
    }
  }

  String _getNotificationTimesSubtitle() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'تحديد الأوقات';
      case AppLanguage.english:
        return 'Select Times';
      case AppLanguage.french:
        return 'Sélectionner les heures';
    }
  }

  String _getNotificationTimesDescription() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'كم مرة تريد أن تتلقى التنبيهات في اليوم؟';
      case AppLanguage.english:
        return 'How many times per day would you like to receive notifications?';
      case AppLanguage.french:
        return 'Combien de fois par jour souhaitez-vous recevoir des notifications ?';
    }
  }

  String _getTimesLabel() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'الأوقات';
      case AppLanguage.english:
        return 'Times';
      case AppLanguage.french:
        return 'Horaires';
    }
  }

  String _getNotificationText() {
    switch (_selectedLanguage) {
      case AppLanguage.arabic:
        return 'التنبيه';
      case AppLanguage.english:
        return 'Notification';
      case AppLanguage.french:
        return 'Notification';
    }
  }

  String _formatPrayerTime(TimeOfDay time) {
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12
        ? (_selectedLanguage == AppLanguage.arabic
              ? 'م'
              : _selectedLanguage == AppLanguage.english
              ? 'PM'
              : 'PM')
        : (_selectedLanguage == AppLanguage.arabic
              ? 'ص'
              : _selectedLanguage == AppLanguage.english
              ? 'AM'
              : 'AM');
    final hour12 = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    return '$hour12:$minute $period';
  }
}
