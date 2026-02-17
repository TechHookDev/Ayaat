import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import '../models/notification_verse.dart';
import '../models/verse.dart';
import 'language_service.dart';
import 'quran_api.dart';

// Permission status for exact alarms
enum ExactAlarmPermissionStatus { granted, denied }

/// Extension to check exact alarm permission on Android
extension ExactAlarmPermission on FlutterLocalNotificationsPlugin {
  Future<ExactAlarmPermissionStatus> requestExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        // Check if we can schedule exact alarms
        final canSchedule = await androidPlugin.canScheduleExactNotifications();
        if (canSchedule ?? false) {
          return ExactAlarmPermissionStatus.granted;
        }
      }
    }
    return ExactAlarmPermissionStatus.denied;
  }
}

/// Service for managing scheduled notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final QuranApiService _quranApi = QuranApiService();

  // Stream to notify when notification is tapped
  static final _notificationTappedController =
      StreamController<int>.broadcast();
  static Stream<int> get notificationTapped =>
      _notificationTappedController.stream;

  static const String _notificationTimesKey = 'notification_times';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _notificationVerseKey = 'notification_verse';
  static const String _notificationModeKey = 'notification_mode'; // 'manual' or 'prayer'
  static const int _baseNotificationId = 1000;
  static const int _daysToSchedule = 30;

  /// Initialize the notification service (without requesting permissions)
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneId = timeZoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneId));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initializationSettings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request notification permissions (should be called when user enables notifications)
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Request notification permission
      final notificationGranted =
          await androidPlugin?.requestNotificationsPermission() ?? false;

      // Request exact alarm permission for scheduled notifications
      final exactAlarmStatus = await requestExactAlarmsPermission();
      final exactAlarmGranted =
          exactAlarmStatus == ExactAlarmPermissionStatus.granted;

      debugPrint(
        'Notification permission: $notificationGranted, Exact alarm: $exactAlarmGranted',
      );

      return notificationGranted;
    } else if (Platform.isIOS) {
      final iosPlugin =
          _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted =
          await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      debugPrint('iOS Notification permission granted: $granted');
      return granted;
    }
    return true;
  }

  /// Request exact alarms permission specifically
  Future<ExactAlarmPermissionStatus> requestExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final canSchedule = await androidPlugin.canScheduleExactNotifications();
        if (canSchedule ?? false) {
          return ExactAlarmPermissionStatus.granted;
        }
      }
    }
    return ExactAlarmPermissionStatus.denied;
  }

  /// Schedule notifications based on prayer times
  Future<List<TimeOfDay>?> schedulePrayerTimes() async {
    // Check notification permission first
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await androidPlugin?.requestNotificationsPermission();
      if (granted != true) {
        debugPrint(
          'Notification permission denied. Cannot schedule prayer times.',
        );
        return null;
      }
    } else if (Platform.isIOS) {
      final bool granted = await requestPermissions();
      if (!granted) {
        debugPrint(
          'iOS Notification permission denied. Cannot schedule prayer times.',
        );
        return null;
      }
    }

    // Check exact alarm permission
    if (Platform.isAndroid) {
      final exactAlarmStatus = await requestExactAlarmsPermission();
      if (exactAlarmStatus != ExactAlarmPermissionStatus.granted) {
        debugPrint('Exact alarm permission not granted.');
        return null;
      }
    }

    try {
      final position = await _determinePosition();
      if (position == null) {
        debugPrint('Could not determine location for prayer times.');
        return null;
      }

      final myCoordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;
      
      final prayerTimes = PrayerTimes.today(myCoordinates, params);
      
      // Add 30 minutes offset to match onboarding logic
      final fajr = prayerTimes.fajr.add(const Duration(minutes: 30));
      final dhuhr = prayerTimes.dhuhr.add(const Duration(minutes: 30));
      final asr = prayerTimes.asr.add(const Duration(minutes: 30));
      final maghrib = prayerTimes.maghrib.add(const Duration(minutes: 30));
      final isha = prayerTimes.isha.add(const Duration(minutes: 30));

      final times = <TimeOfDay>[
        TimeOfDay.fromDateTime(fajr),
        TimeOfDay.fromDateTime(dhuhr),
        TimeOfDay.fromDateTime(asr),
        TimeOfDay.fromDateTime(maghrib),
        TimeOfDay.fromDateTime(isha),
      ];

      debugPrint('Scheduling prayer times (with +30min offset): $times');
      
      // Save mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationModeKey, 'prayer');
      
      // Reuse existing logic to schedule these times
      final success = await scheduleMultipleDaily(times);
      return success ? times : null;

    } catch (e) {
      debugPrint('Error scheduling prayer times: $e');
      return null;
    }
  }

  /// Get current notification mode ('manual' or 'prayer')
  Future<String> getNotificationMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notificationModeKey) ?? 'manual';
  }

  /// Set notification mode
  Future<void> setNotificationMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationModeKey, mode);
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    } 

    return await Geolocator.getCurrentPosition();
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final verseNumber = int.parse(response.payload!);
        debugPrint('Notification tapped: verse $verseNumber');
        // Add to stream so the app can listen and navigate
        _notificationTappedController.add(verseNumber);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Check if the app was launched by tapping a notification
  Future<int?> getLaunchVerseNumber() async {
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) {
        try {
          return int.parse(payload);
        } catch (e) {
          debugPrint('Error parsing launch payload: $e');
        }
      }
    }
    return null;
  }

  /// Check and reschedule notifications if needed (e.g. on app start)
  Future<void> rescheduleNotifications() async {
     final prefs = await SharedPreferences.getInstance();
     final enabled = prefs.getBool(_notificationsEnabledKey) ?? false;
     if (!enabled) return;

     final timesJson = prefs.getString(_notificationTimesKey);
     if (timesJson == null) return;

      try {
      final List<dynamic> decoded = jsonDecode(timesJson);
      final times =  decoded
          .map(
            (t) =>
                TimeOfDay(hour: t['hour'] as int, minute: t['minute'] as int),
          )
          .toList();

      // For now, naive approach: just reschedule everything to replenish the 30 days
      // A better optimization would be to check pending notifications count.
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      
      // If we have less than 5 days worth of notifications, top up.
      // Assuming 1 notification per day = 5 notifications.
      final minRequired = times.length * 5; 
      
      if (pendingNotifications.length < minRequired) {
         debugPrint('Replenishing scheduled notifications...');
         await scheduleMultipleDaily(times);
      } else {
        debugPrint('Notifications Schedule is healthy: ${pendingNotifications.length} pending.');
      }

    } catch (e) {
      debugPrint('Error checking reschedule: $e');
    }
  }

  /// Schedule multiple daily notifications at specified times for the next 30 days
  Future<bool> scheduleMultipleDaily(List<TimeOfDay> times) async {
    // Check notification permission first
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await androidPlugin?.requestNotificationsPermission();
      if (granted != true) {
        debugPrint(
          'Notification permission decreased/denied. Cannot schedule.',
        );
        return false;
      }
    } else if (Platform.isIOS) {
      final bool granted = await requestPermissions();
      if (!granted) {
        debugPrint(
          'iOS Notification permission denied. Cannot schedule notifications.',
        );
        return false;
      }
    }

    // Check exact alarm permission (Android only)
    if (Platform.isAndroid) {
      final exactAlarmStatus = await requestExactAlarmsPermission();
      if (exactAlarmStatus != ExactAlarmPermissionStatus.granted) {
        debugPrint(
          'Exact alarm permission not granted. Cannot schedule notifications.',
        );
        return false;
      }
    }
    
     debugPrint('Scheduling notifications for the next $_daysToSchedule days.');

    final prefs = await SharedPreferences.getInstance();

    // Save the times
    final timesJson = times
        .map((t) => {'hour': t.hour, 'minute': t.minute})
        .toList();
    await prefs.setString(_notificationTimesKey, jsonEncode(timesJson));
    await prefs.setBool(_notificationsEnabledKey, true);

    // Cancel all existing to avoid duplicates or mess
    await _notifications.cancelAll();

    // Schedule for the next 30 days
    final langService = LanguageService();
    final currentLanguage = await langService.getCurrentLanguage();
    
    // Create a Set to ensure uniqueness within this batch
    final Set<int> scheduledVerseIds = {};
    
    // Pre-fetech verses could be slow, so we do it in the loop
    // But to ensure we are not blocking excessively, we might need to yield?
    
    for (int day = 0; day < _daysToSchedule; day++) {
       for (int i = 0; i < times.length; i++) {
        final notificationId = _baseNotificationId + (day * 100) + i; // Unique ID per day per time
        
        // Get a random verse
        Verse? verse;
        int attempts = 0;
        
        // Try to find a verse we haven't scheduled in this batch
        while (attempts < 5) {
           // Small delay to prevent UI freeze if valid
           await Future.delayed(Duration(milliseconds: 10));
           final v = await _quranApi.getRandomVerse(language: currentLanguage);
           if (!scheduledVerseIds.contains(v.number)) {
             verse = v;
             scheduledVerseIds.add(v.number);
             break;
           }
           attempts++;
        }
        // Fallback if we couldn't find unique
        verse ??= await _quranApi.getRandomVerse(language: currentLanguage);

        await _scheduleSingleNotification(
          id: notificationId,
          verse: verse,
          hour: times[i].hour,
          minute: times[i].minute,
          daysAhead: day,
        );
      }
    }

    debugPrint('Scheduled notifications for $_daysToSchedule days');
    return true;
  }

  /// Schedule a single notification for a specific day in the future
  Future<void> _scheduleSingleNotification({
    required int id,
    required Verse verse,
    required int hour,
    required int minute,
    required int daysAhead,
  }) async {
    try {
      
      // Calculate date: Today + daysAhead
      var scheduledDate = _nextInstanceOfTime(hour, minute);
      if (daysAhead > 0) {
        scheduledDate = scheduledDate.add(Duration(days: daysAhead));
      }

      await _notifications.zonedSchedule(
        id: id,
        title: 'آيات - Ayaat',
        body: verse.text,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'ayaat_daily_v2', 
            'Daily Quran Verse',
            channelDescription: 'Daily Quran verse notifications',
            importance: Importance.max,
            priority: Priority.max,
            styleInformation: BigTextStyleInformation(
              verse.text,
              contentTitle: 'آيات - Ayaat',
              summaryText: verse.reference,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: verse.number.toString(),
      );
    } catch (e) {
      debugPrint('Error scheduling notification $id: $e');
    }
  }

  /// Get the last notification verse data
  Future<NotificationVerse?> getNotificationVerse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verseJson = prefs.getString(_notificationVerseKey);
      if (verseJson != null) {
        return NotificationVerse.fromJson(jsonDecode(verseJson));
      }
    } catch (e) {
      debugPrint('Error getting notification verse: $e');
    }
    return null;
  }

  /// Clear notification verse data
  Future<void> clearNotificationVerse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationVerseKey);
  }

  /// Calculate the next instance of the specified time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, false);
  }

  /// Check if notifications are enabled
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  /// Get all scheduled notification times
  Future<List<TimeOfDay>> getScheduledTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final timesJson = prefs.getString(_notificationTimesKey);

    if (timesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(timesJson);
      return decoded
          .map(
            (t) =>
                TimeOfDay(hour: t['hour'] as int, minute: t['minute'] as int),
          )
          .toList();
    } catch (e) {
      debugPrint('Error parsing notification times: $e');
      return [];
    }
  }

  /// Get the scheduled notification time (legacy - returns first time or null)
  Future<TimeOfDay?> getScheduledTime() async {
    final times = await getScheduledTimes();
    return times.isNotEmpty ? times.first : null;
  }

  /// Schedule a daily notification at the specified time (legacy support)
  Future<bool> scheduleDaily(int hour, int minute) async {
    return await scheduleMultipleDaily([TimeOfDay(hour: hour, minute: minute)]);
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Set onboarding completion status
  Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, complete);
  }

  /// Send an immediate test notification
  Future<void> sendTestNotification() async {
    try {
      final langService = LanguageService();
      final currentLanguage = await langService.getCurrentLanguage();
      final verse = await _quranApi.getRandomVerse(language: currentLanguage);

      await _notifications.show(
        id: 99, // Different ID for test notifications
        title: 'آيات - Ayaat',
        body: verse.text,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'ayaat_daily_v2', // Updated to match new channel ID
            'Daily Quran Verse',
            channelDescription: 'Daily Quran verse notifications',
            importance: Importance.max,
            priority: Priority.max,
            styleInformation: BigTextStyleInformation(
              verse.text,
              contentTitle: 'آيات - Ayaat',
              summaryText: verse.reference,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: verse.number.toString(),
      );
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }
}
