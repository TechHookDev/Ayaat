import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final LanguageService _languageService = LanguageService();
  bool _notificationsEnabled = false;
  final List<TimeOfDay> _notificationTimes = [];
  List<TimeOfDay> _prayerTimes = [];
  AppLanguage _currentLanguage = AppLanguage.arabic;
  String _notificationMode = 'manual';
  bool _isLoading = true;
  bool _isAboutExpanded = false;
  String _appVersion = '1.0.9'; // Fallback

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notificationService.isEnabled();
    final times = await _notificationService.getScheduledTimes();
    final mode = await _notificationService.getNotificationMode();
    final language = await _languageService.getCurrentLanguage();

    debugPrint('Settings: _loadSettings - Enabled: $enabled, Mode: $mode, Times: $times');

    setState(() {
      _notificationsEnabled = enabled;
      _currentLanguage = language;
      _notificationMode = mode;
      _notificationTimes.clear();
      _prayerTimes.clear();
      
      if (times.isNotEmpty) {
        if (mode == 'prayer') {
          _prayerTimes.addAll(times);
          // Set default manual times if we don't have them
          _notificationTimes.add(const TimeOfDay(hour: 9, minute: 0));
        } else {
           _notificationTimes.addAll(times);
        }
      } else {
        // Default if empty
        _notificationTimes.add(const TimeOfDay(hour: 9, minute: 0));
      }
      
      _isLoading = false;
    });

    // Load app version separately
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
    debugPrint('Settings: _loadSettings complete - Version: $_appVersion');
  }

  // Translation methods
  String _getSettingsTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'الإعدادات';
      case AppLanguage.english:
        return 'Settings';
      case AppLanguage.french:
        return 'Paramètres';
    }
  }

  String _getNotificationsTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'التنبيهات';
      case AppLanguage.english:
        return 'Notifications';
      case AppLanguage.french:
        return 'Notifications';
    }
  }

  String _getEnableNotifications() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'تفعيل التنبيهات';
      case AppLanguage.english:
        return 'Enable Notifications';
      case AppLanguage.french:
        return 'Activer les Notifications';
    }
  }

  String _getNotificationTimesTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'مواعيد التنبيهات';
      case AppLanguage.english:
        return 'Notification Times';
      case AppLanguage.french:
        return 'Heures des Notifications';
    }
  }

  String _getAddNewTime() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'إضافة تنبيه';
      case AppLanguage.english:
        return 'Add Alarm';
      case AppLanguage.french:
        return 'Ajouter une Alarme';
    }
  }

  String _getManualModeTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'توقيت يدوي';
      case AppLanguage.english:
        return 'Manual Times';
      case AppLanguage.french:
        return 'Horaires Manuels';
    }
  }

  String _getPrayerModeTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'أوقات الصلاة';
      case AppLanguage.english:
        return 'Prayer Times';
      case AppLanguage.french:
        return 'Horaires de Prières';
    }
  }

  String _getLanguageTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'اللغة';
      case AppLanguage.english:
        return 'Language';
      case AppLanguage.french:
        return 'Langue';
    }
  }

  String _getAboutTitle() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'عن التطبيق';
      case AppLanguage.english:
        return 'About';
      case AppLanguage.french:
        return 'À Propos';
    }
  }

  String _getAppDescription() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'تطبيق آيات يذكرك بقراءة القرآن في أوقات محددة، ويساعدك على البقاء على تواصل مع كتاب الله';
      case AppLanguage.english:
        return 'Ayaat reminds you to read the Quran at specific set times, helping you stay connected with the Book of Allah';
      case AppLanguage.french:
        return 'Ayaat vous rappelle de lire le Coran à des moments précis, vous aidant à rester connecté avec le Livre d\'Allah';
    }
  }

  String _getDevelopedBy() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'جميع الحقوق محفوظة';
      case AppLanguage.english:
        return 'All rights reserved';
      case AppLanguage.french:
        return 'Tous droits réservés';
    }
  }

  String _getDuaaMessage() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'لا تنسونا من صالح دعائكم';
      case AppLanguage.english:
        return 'Please remember us in your prayers';
      case AppLanguage.french:
        return 'N\'oubliez pas de nous garder dans vos prières';
    }
  }

  String _getContactUs() {
    switch (_currentLanguage) {
      case AppLanguage.arabic:
        return 'اتصل بنا';
      case AppLanguage.english:
        return 'Contact Us';
      case AppLanguage.french:
        return 'Contactez-nous';
    }
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    await _languageService.setLanguage(language);
    setState(() {
      _currentLanguage = language;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) return;
    }

    setState(() {
      _notificationsEnabled = value;
    });

    if (value) {
      if (_notificationMode == 'prayer') {
        await _notificationService.schedulePrayerTimes();
      } else {
        await _notificationService.scheduleMultipleDaily(_notificationTimes);
      }
    } else {
      await _notificationService.cancelAll();
    }
  }

  Future<void> _changeNotificationMode(String mode) async {
    if (_notificationMode == mode) return;

    if (mode == 'prayer') {
      // Show loading snackbar/indicator if needed, but don't block UI
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar(); // Hide previous if any
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _currentLanguage == AppLanguage.arabic
                      ? 'جاري تحديد الموقع وحساب الأوقات...'
                      : _currentLanguage == AppLanguage.french
                          ? 'Localisation et calcul des horaires...'
                          : 'Locating and calculating times...',
                  style: GoogleFonts.amiri(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 3000), // Longer duration
          backgroundColor: const Color(0xFF0D1B2A),
          behavior: SnackBarBehavior.floating, // Floating above bottom
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    setState(() {
      _notificationMode = mode;
      // Optimistically switch, might revert if fails
    });

    await _notificationService.setNotificationMode(mode);

    if (_notificationsEnabled) {
      if (mode == 'prayer') {
        final times = await _notificationService.schedulePrayerTimes();
        if (times == null) {
          // If failed (e.g. location denied), revert to manual
          if (mounted) {
             setState(() {
               _notificationMode = 'manual';
             });
             await _notificationService.setNotificationMode('manual');
             await _notificationService.scheduleMultipleDaily(_notificationTimes);
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text(
                   _currentLanguage == AppLanguage.arabic
                     ? 'تعذر تفعيل أوقات الصلاة. يرجى التحقق من إعدادات الموقع.'
                     : _currentLanguage == AppLanguage.french
                       ? 'Impossible d\'activer les heures de prière. Veuillez vérifier les paramètres de localisation.'
                       : 'Could not enable prayer times. Please check location permissions.',
                   style: GoogleFonts.amiri(color: Colors.white),
                 ),
                 backgroundColor: Colors.redAccent,
                 behavior: SnackBarBehavior.floating,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                 margin: const EdgeInsets.all(16),
               ),
             );
          }
        } else {
           if (mounted) {
             setState(() {
               _prayerTimes = times;
             });
             ScaffoldMessenger.of(context).hideCurrentSnackBar();
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text(
                   _currentLanguage == AppLanguage.arabic
                     ? 'تم تفعيل أوقات الصلاة بنجاح'
                     : _currentLanguage == AppLanguage.french
                       ? 'Heures de prière activées avec succès'
                       : 'Prayer times enabled successfully',
                   style: GoogleFonts.amiri(color: Colors.white),
                 ),
                 backgroundColor: const Color(0xFF0D1B2A),
                 behavior: SnackBarBehavior.floating,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                 margin: const EdgeInsets.all(16),
               ),
             );
           }
        }
      } else {
        await _notificationService.scheduleMultipleDaily(_notificationTimes);
      }
    }
  }

  Future<void> _addNotificationTime() async {
    if (_notificationTimes.length >= 5) return;

    final picked = await _showCustomTimePicker(
      context,
      const TimeOfDay(hour: 12, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _notificationTimes.add(picked);
        _notificationTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });

      if (_notificationsEnabled) {
        await _notificationService.scheduleMultipleDaily(_notificationTimes);
      }
    }
  }

  Future<void> _editNotificationTime(int index) async {
    final picked = await _showCustomTimePicker(
      context,
      _notificationTimes[index],
    );

    if (picked != null) {
      setState(() {
        _notificationTimes[index] = picked;
        _notificationTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });

      if (_notificationsEnabled) {
        await _notificationService.scheduleMultipleDaily(_notificationTimes);
      }
    }
  }

  Future<void> _removeNotificationTime(int index) async {
    if (_notificationTimes.length <= 1) return;

    setState(() {
      _notificationTimes.removeAt(index);
    });

    if (_notificationsEnabled) {
      await _notificationService.scheduleMultipleDaily(_notificationTimes);
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'contact@techhook.dev',
      query: 'subject=Ayaat App Inquiry',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
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
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _buildSettings(),
              ),
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
            child: Center(
              child: Text(
                _getSettingsTitle(),
                style: GoogleFonts.amiri(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Notifications Section
          _buildSectionCard(
            icon: Icons.notifications_active,
            title: _getNotificationsTitle(),
            children: [
              // Enable toggle - custom layout for Arabic (switch left, text right)
              InkWell(
                onTap: () => _toggleNotifications(!_notificationsEnabled),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // For Arabic: Switch on left, Text on right
                      if (_currentLanguage == AppLanguage.arabic) ...[
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeTrackColor: const Color(0xFFFFD700),
                          activeColor: const Color(0xFF0D1B2A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getEnableNotifications(),
                            style: GoogleFonts.amiri(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ] else ...[
                        // For English/French: Text on left, Switch on right (normal)
                        Expanded(
                          child: Text(
                            _getEnableNotifications(),
                            style: GoogleFonts.amiri(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeTrackColor: const Color(0xFFFFD700),
                          activeColor: const Color(0xFF0D1B2A),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_notificationsEnabled) ...[
                const Divider(color: Colors.white24, height: 1),
                
                // Mode Selection
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _changeNotificationMode('manual'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _notificationMode == 'manual' 
                                    ? const Color(0xFFFFD700) 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getManualModeTitle(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.amiri(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _notificationMode == 'manual'
                                      ? const Color(0xFF0D1B2A)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _changeNotificationMode('prayer'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _notificationMode == 'prayer' 
                                    ? const Color(0xFFFFD700) 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getPrayerModeTitle(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.amiri(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _notificationMode == 'prayer'
                                      ? const Color(0xFF0D1B2A)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_notificationMode == 'manual') ...[
                  const Divider(color: Colors.white24, height: 1),
                  // Time slots - centered
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _getNotificationTimesTitle(),
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: List.generate(
                            _notificationTimes.length,
                            (index) => _buildTimeChip(index),
                          ),
                        ),
                        if (_notificationTimes.length < 5) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: _buildGoldButton(
                              icon: Icons.add,
                              label: _getAddNewTime(),
                              onTap: _addNotificationTime,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                   // Prayer Times Info
                   Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mosque, 
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentLanguage == AppLanguage.arabic
                              ? 'سيتم إرسال التنبيهات بعد 30 دقيقة من مواقيت الصلاة أدناه'
                              : _currentLanguage == AppLanguage.french
                                  ? 'Les notifications seront envoyées 30 minutes après les heures de prière ci-dessous'
                                  : 'Notifications will be sent 30 minutes after the prayer times below',
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                         Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: List.generate(
                            _prayerTimes.length,
                            (index) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                              ),
                              child: Text(
                                _formatTime(_prayerTimes[index]),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFD700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                   ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Language Section - left aligned
          _buildSectionCard(
            icon: Icons.language,
            title: _getLanguageTitle(),
            children: [
              _buildLanguageOption(AppLanguage.arabic, 'العربية'),
              const Divider(color: Colors.white24, height: 1),
              _buildLanguageOption(AppLanguage.english, 'English'),
              const Divider(color: Colors.white24, height: 1),
              _buildLanguageOption(AppLanguage.french, 'Français'),
            ],
          ),
          const SizedBox(height: 20),
          // About Section - Expandable
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header - clickable to expand/collapse
                InkWell(
                  onTap: () {
                    setState(() {
                      _isAboutExpanded = !_isAboutExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: const Color(0xFFFFD700),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getAboutTitle(),
                          style: GoogleFonts.amiri(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _isAboutExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Expandable content with smooth animation
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _isAboutExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // App Name
                              Text(
                                'Ayaat',
                                style: GoogleFonts.amiri(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFD700),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Description
                              Text(
                                _getAppDescription(),
                                style: GoogleFonts.amiri(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                                textDirection:
                                    _currentLanguage == AppLanguage.arabic
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _getDevelopedBy(),
                                style: GoogleFonts.amiri(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // TechHook Logo
                              InkWell(
                                onTap: () async {
                                  final Uri url = Uri.parse('https://techhook.dev');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Image.asset(
                                    'assets/techhook_logo.png',
                                    height: 50,
                                    width: 50,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Duaa message
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFD700,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _getDuaaMessage(),
                                  style: GoogleFonts.amiri(
                                    fontSize: 14,
                                    color: const Color(0xFFFFD700),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 20),


                              // Contact button
                              Center(
                                child: InkWell(
                                  onTap: _launchEmail,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFFD700,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFFD700).withOpacity(0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.email,
                                          color: const Color(0xFFFFD700),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _getContactUs(),
                                          style: GoogleFonts.amiri(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFFFD700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Version
          Text(
            'v$_appVersion',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header - centered
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFFFFD700), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12
        ? (_currentLanguage == AppLanguage.arabic ? 'م' : 'PM')
        : (_currentLanguage == AppLanguage.arabic ? 'ص' : 'AM');
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  Widget _buildTimeChip(int index) {
    final time = _notificationTimes[index];
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12
        ? (_currentLanguage == AppLanguage.arabic
              ? 'م'
              : 'PM')
        : (_currentLanguage == AppLanguage.arabic
              ? 'ص'
              : 'AM');
    final hour12 = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final timeStr = '$hour12:$minute $period';

    return InkWell(
      onTap: () => _editNotificationTime(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeStr,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
              ),
            ),
            if (_notificationTimes.length > 1) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _removeNotificationTime(index),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(AppLanguage language, String label) {
    final isSelected = _currentLanguage == language;

    return ListTile(
      onTap: () => _changeLanguage(language),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        label,
        style: GoogleFonts.amiri(
          fontSize: 18,
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 16,
                color: Color(0xFF0D1B2A),
              ),
            )
          : Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
            ),
    );
  }

  Widget _buildGoldButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.amiri(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<TimeOfDay?> _showCustomTimePicker(BuildContext context, TimeOfDay initialTime) async {
    int selectedHour = initialTime.hourOfPeriod;
    int selectedMinute = initialTime.minute;
    String selectedPeriod = initialTime.period == DayPeriod.am ? 'AM' : 'PM';
    if (selectedHour == 0) selectedHour = 12; // Handle 12 AM/PM logic for display

    // Scroll controllers
    late FixedExtentScrollController hourController;
    late FixedExtentScrollController minuteController;
    late FixedExtentScrollController periodController;

    hourController = FixedExtentScrollController(initialItem: selectedHour - 1);
    minuteController = FixedExtentScrollController(initialItem: selectedMinute);
    periodController = FixedExtentScrollController(initialItem: initialTime.period == DayPeriod.am ? 0 : 1);

    return await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: 350,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          _currentLanguage == AppLanguage.arabic
                              ? 'إلغاء'
                              : _currentLanguage == AppLanguage.french
                                  ? 'Annuler'
                                  : 'Cancel',
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                      Text(
                        _currentLanguage == AppLanguage.arabic
                            ? 'اختر الوقت'
                            : _currentLanguage == AppLanguage.french
                                ? 'Choisir l\'heure'
                                : 'Select Time',
                        style: GoogleFonts.amiri(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Calculate final TimeOfDay
                          int hour = hourController.selectedItem + 1;
                          final minute = minuteController.selectedItem;
                          final periodIndex = periodController.selectedItem; // 0=AM, 1=PM
                          
                          // Convert back to 24h
                          if (periodIndex == 0) { // AM
                            if (hour == 12) hour = 0;
                          } else { // PM
                            if (hour != 12) hour += 12;
                          }
                          
                          Navigator.pop(context, TimeOfDay(hour: hour, minute: minute));
                        },
                        child: Text(
                          _currentLanguage == AppLanguage.arabic
                              ? 'تم'
                              : _currentLanguage == AppLanguage.french
                                  ? 'OK'
                                  : 'Done',
                          style: GoogleFonts.amiri(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Wheel Pickers
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Selection Highlight
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: const Color(0xFFFFD700).withOpacity(0.5), 
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        // Wheels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Hours
                            SizedBox(
                              width: 70,
                              child: ListWheelScrollView.useDelegate(
                                controller: hourController,
                                itemExtent: 50,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  // HapticFeedback.selectionClick(); // Optional
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 12,
                                  builder: (context, index) {
                                    return Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              ":",
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Minutes
                            SizedBox(
                              width: 70,
                              child: ListWheelScrollView.useDelegate(
                                controller: minuteController,
                                itemExtent: 50,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: const FixedExtentScrollPhysics(),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 60,
                                  builder: (context, index) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Period (AM/PM)
                            SizedBox(
                              width: 70,
                              child: ListWheelScrollView.useDelegate(
                                controller: periodController,
                                itemExtent: 50,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: const FixedExtentScrollPhysics(),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 2,
                                  builder: (context, index) {
                                    final text = _currentLanguage == AppLanguage.arabic
                                        ? (index == 0 ? 'ص' : 'م')
                                        : (index == 0 ? 'AM' : 'PM');
                                    return Center(
                                      child: Text(
                                        text,
                                        style: GoogleFonts.amiri(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFFFD700),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
