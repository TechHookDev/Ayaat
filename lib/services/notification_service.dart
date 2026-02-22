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
        } else {
          final granted = await androidPlugin.requestExactAlarmsPermission();
          if (granted ?? false) {
            return ExactAlarmPermissionStatus.granted;
          }
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
  static const String _notificationModeKey =
      'notification_mode'; // 'manual' or 'prayer'
  static const int _baseNotificationId = 1000;
  static const int _daysToSchedule = 7;

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
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request notification permissions (should be called when user enables notifications)
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
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
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
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
        } else {
          final granted = await androidPlugin.requestExactAlarmsPermission();
          if (granted ?? false) {
            return ExactAlarmPermissionStatus.granted;
          }
        }
      }
    }
    return ExactAlarmPermissionStatus.denied;
  }

  static const String _lastKnownLatKey = 'last_known_lat';
  static const String _lastKnownLngKey = 'last_known_lng';

  /// Schedule notifications based on prayer times
  Future<List<TimeOfDay>?> schedulePrayerTimes({bool useDelay = false}) async {
    // Check notification permission first
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await androidPlugin
          ?.requestNotificationsPermission();
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

      // Save valid location for future travel checks
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_lastKnownLatKey, position.latitude);
      await prefs.setDouble(_lastKnownLngKey, position.longitude);

      final myCoordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final prayerTimes = PrayerTimes.today(myCoordinates, params);

      // Add 30 minutes offset to match onboarding logic
      final fajr = prayerTimes.fajr.toLocal().add(const Duration(minutes: 30));
      final dhuhr = prayerTimes.dhuhr.toLocal().add(
        const Duration(minutes: 30),
      );
      final asr = prayerTimes.asr.toLocal().add(const Duration(minutes: 30));
      final maghrib = prayerTimes.maghrib.toLocal().add(
        const Duration(minutes: 30),
      );
      final isha = prayerTimes.isha.toLocal().add(const Duration(minutes: 30));

      final times = <TimeOfDay>[
        TimeOfDay.fromDateTime(fajr),
        TimeOfDay.fromDateTime(dhuhr),
        TimeOfDay.fromDateTime(asr),
        TimeOfDay.fromDateTime(maghrib),
        TimeOfDay.fromDateTime(isha),
      ];

      debugPrint(
        '>> [DEBUG] Calculated Prayer Times (Today, with +30min offset):',
      );
      debugPrint('   - Fajr: $fajr');
      debugPrint('   - Dhuhr: $dhuhr');
      debugPrint('   - Asr: $asr');
      debugPrint('   - Maghrib: $maghrib');
      debugPrint('   - Isha: $isha');

      // Save mode
      await prefs.setString(_notificationModeKey, 'prayer');

      // Await scheduling to ensure background tasks complete before app closure
      final success = await scheduleMultipleDaily(
        times,
        useDelay: useDelay,
        isPrayerMode: true,
      );
      if (!success) {
        debugPrint('Background scheduling failed');
      }

      // Return times
      return times;
    } catch (e) {
      debugPrint('Error scheduling prayer times: $e');
      return null;
    }
  }

  /// Check if location has changed significantly (>10km) and update prayer times if so
  Future<void> checkLocationAndUpdate() async {
    try {
      final mode = await getNotificationMode();
      if (mode != 'prayer') return;

      final prefs = await SharedPreferences.getInstance();
      final lastLat = prefs.getDouble(_lastKnownLatKey);
      final lastLng = prefs.getDouble(_lastKnownLngKey);

      if (lastLat == null || lastLng == null) return;

      debugPrint('Checking for location change (Travel Auto-Update)...');

      // Check exact alarm permission first (Android 14+)
      if (Platform.isAndroid) {
        final exactAlarmStatus = await requestExactAlarmsPermission();
        if (exactAlarmStatus != ExactAlarmPermissionStatus.granted) {
          debugPrint(
            'Exact alarm permission revoked. Cannot auto-update prayer times.',
          );
          return;
        }
      }

      // Get current location with low accuracy (fast & battery efficient)
      // We don't use _determinePosition here because we want to be very gentle
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      final distanceInMeters = Geolocator.distanceBetween(
        lastLat,
        lastLng,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      debugPrint(
        'Distance from last location: ${distanceInMeters.toStringAsFixed(0)} meters',
      );

      // If moved more than 10km (10,000 meters)
      if (distanceInMeters > 10000) {
        debugPrint(
          'Significant location change detected. Updating prayer times...',
        );
        await schedulePrayerTimes(useDelay: false); // Update immediately
      } else {
        debugPrint('Location unchanged or movement insignificant.');
      }
    } catch (e) {
      debugPrint('Error checking location update: $e');
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
      debugPrint('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever.');
      return null;
    }

    // 1. Try last known position (fastest)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint('Using last known position: $lastKnown');
        return lastKnown;
      }
    } catch (e) {
      debugPrint('Error getting last known position: $e');
    }

    // 2. Try current position with low accuracy (faster)
    try {
      debugPrint('Getting current position (low accuracy)...');
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Error getting low accuracy position: $e');

      // 3. Retry with high accuracy if low failed (maybe needs GPS)
      try {
        debugPrint('Retrying with high accuracy...');
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('Error getting high accuracy position: $e');
        return null;
      }
    }
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
    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();

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
  Future<void> rescheduleNotifications({bool useDelay = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsEnabledKey) ?? false;
    if (!enabled) return;

    final timesJson = prefs.getString(_notificationTimesKey);
    if (timesJson == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(timesJson);
      final times = decoded
          .map(
            (t) =>
                TimeOfDay(hour: t['hour'] as int, minute: t['minute'] as int),
          )
          .toList();

      // For now, naive approach: just reschedule everything to replenish the 30 days
      // A better optimization would be to check pending notifications count.
      final pendingNotifications = await _notifications
          .pendingNotificationRequests();

      // If we have less than 5 days worth of notifications, top up.
      // Assuming 1 notification per day = 5 notifications.
      final minRequired = times.length * 5;

      if (pendingNotifications.length < minRequired) {
        debugPrint('Replenishing scheduled notifications...');
        await scheduleMultipleDaily(times, useDelay: useDelay);
      } else {
        debugPrint(
          'Notifications Schedule is healthy: ${pendingNotifications.length} pending.',
        );
      }
    } catch (e) {
      debugPrint('Error checking reschedule: $e');
    }
  }

  /// Schedule multiple daily notifications at specified times for the next 7 days
  Future<bool> scheduleMultipleDaily(
    List<TimeOfDay> times, {
    bool useDelay = false,
    bool isPrayerMode = false,
  }) async {
    // delay to let the app load first if requested
    if (useDelay) {
      await Future.delayed(const Duration(seconds: 5));
    }

    // Check notification permission first
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await androidPlugin
          ?.requestNotificationsPermission();
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

    if (!isPrayerMode) {
      if (prefs.getString(_notificationModeKey) == 'prayer') {
        isPrayerMode = true;
      }
    }

    // Save the times
    final timesJson = times
        .map((t) => {'hour': t.hour, 'minute': t.minute})
        .toList();
    await prefs.setString(_notificationTimesKey, jsonEncode(timesJson));
    await prefs.setBool(_notificationsEnabledKey, true);

    // Move cancelAll down to right before we start succeeding in scheduling

    // Schedule for the next 7 days
    final langService = LanguageService();
    final currentLanguage = await langService.getCurrentLanguage();

    final totalVersesNeeded = _daysToSchedule * times.length;
    final batchSize = 7;

    debugPrint(
      'Fetching and scheduling $totalVersesNeeded truly random verses in batches of $batchSize...',
    );

    int currentVerseIndex = 0;
    bool hasCancelledOld = false;

    try {
      Coordinates? myCoordinates;
      CalculationParameters? params;
      if (isPrayerMode) {
        final lastLat = prefs.getDouble(_lastKnownLatKey);
        final lastLng = prefs.getDouble(_lastKnownLngKey);
        if (lastLat != null && lastLng != null) {
          myCoordinates = Coordinates(lastLat, lastLng);
          params = CalculationMethod.muslim_world_league.getParameters();
          params.madhab = Madhab.shafi;
        } else {
          isPrayerMode = false;
        }
      }

      for (int i = 0; i < totalVersesNeeded; i += batchSize) {
        final remaining = totalVersesNeeded - i;
        final currentBatchSize = remaining < batchSize ? remaining : batchSize;

        final List<Future<Verse>> batchFutures = [];
        for (int j = 0; j < currentBatchSize; j++) {
          batchFutures.add(
            _quranApi.getRandomVerse(language: currentLanguage).catchError((e) {
              debugPrint('API Error fetching verse, using fallback: $e');
              return Verse(
                number: 1,
                text: currentLanguage == AppLanguage.arabic
                    ? 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'
                    : currentLanguage == AppLanguage.french
                    ? 'Au nom d\'Allah, le Tout Miséricordieux, le Très Miséricordieux.'
                    : 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
                numberInSurah: 1,
                surahName: 'سُورَةُ ٱلْفَاتِحَةِ',
                surahEnglishName: 'Al-Faatiha',
                surahNumber: 1,
              );
            }),
          );
        }

        // Wait for batch
        final batchVerses = await Future.wait(batchFutures);

        if (!hasCancelledOld) {
          await _notifications.cancelAll();
          hasCancelledOld = true;
        }

        // Schedule THIS batch
        for (final verse in batchVerses) {
          final day = currentVerseIndex ~/ times.length;
          final timeIndex = currentVerseIndex % times.length;

          int hour = times[timeIndex].hour;
          int minute = times[timeIndex].minute;

          if (isPrayerMode && myCoordinates != null && params != null) {
            final targetDate = DateTime.now().add(Duration(days: day));
            final dateComponents = DateComponents(
              targetDate.year,
              targetDate.month,
              targetDate.day,
            );
            final dailyPrayerTimes = PrayerTimes(
              myCoordinates,
              dateComponents,
              params,
            );

            DateTime prayerTarget;
            switch (timeIndex) {
              case 0:
                prayerTarget = dailyPrayerTimes.fajr;
                break;
              case 1:
                prayerTarget = dailyPrayerTimes.dhuhr;
                break;
              case 2:
                prayerTarget = dailyPrayerTimes.asr;
                break;
              case 3:
                prayerTarget = dailyPrayerTimes.maghrib;
                break;
              case 4:
                prayerTarget = dailyPrayerTimes.isha;
                break;
              default:
                prayerTarget = dailyPrayerTimes.fajr;
                break;
            }
            prayerTarget = prayerTarget.toLocal().add(
              const Duration(minutes: 30),
            );
            hour = prayerTarget.hour;
            minute = prayerTarget.minute;
          }

          final notificationId = _baseNotificationId + (day * 100) + timeIndex;

          await _scheduleSingleNotification(
            id: notificationId,
            verse: verse,
            hour: hour,
            minute: minute,
            daysAhead: day,
          );

          currentVerseIndex++;
        }

        debugPrint(
          'Scheduled random verses up to index $currentVerseIndex / $totalVersesNeeded',
        );

        // Delay between batches to respect rate limits while maintaining OS speed
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      debugPrint(
        'Scheduled fully random notifications for $_daysToSchedule days.',
      );
      return true;
    } catch (e) {
      debugPrint('Error during batch scheduling: $e');
      return false;
    }
  }

  /// Schedule a single notification for a specific day in the future
  Future<void> _scheduleSingleNotification({
    required int id,
    required Verse verse,
    required int hour,
    required int minute,
    required int daysAhead,
  }) async {
    // Declare variables outside try block so they're accessible in catch
    var actualId = id;
    try {
      // Calculate date: Today + daysAhead
      // FIX: Use _nextInstanceOfTime ONLY for finding the base time for "today" logic
      // if we want to be strict.
      // ACTUALLY: The simplest way is to construct the date for Today,
      // check if it's passed (if so, it doesn't matter for daysAhead > 0,
      // but for daysAhead == 0 we might want to skip or show immediately?
      // The requirement is to schedule for future.

      final now = tz.TZDateTime.now(tz.local);
      final targetDay = now.add(Duration(days: daysAhead));

      var scheduledDate = tz.TZDateTime(
        tz.local,
        targetDay.year,
        targetDay.month,
        targetDay.day,
        hour,
        minute,
      );

      // If the resulting time is in the past, we shouldn't schedule it.
      // (This happens if daysAhead=0 and the time has already passed today)
      // CRITICAL FIX: If the time is in the past, try to push to future days
      var actualDaysAhead = daysAhead;
      while (scheduledDate.isBefore(now) &&
          actualDaysAhead < _daysToSchedule - 1) {
        actualDaysAhead++;
        final nextDay = now.add(Duration(days: actualDaysAhead));
        scheduledDate = tz.TZDateTime(
          tz.local,
          nextDay.year,
          nextDay.month,
          nextDay.day,
          hour,
          minute,
        );
      }

      // If we still couldn't find a future time within the window, skip this notification
      if (scheduledDate.isBefore(now)) {
        debugPrint(
          '>> [DEBUG] Skipping past time at boundary: $scheduledDate (daysAhead=$actualDaysAhead, max=$_daysToSchedule)',
        );
        return;
      }

      // If we pushed to a different day, update the ID to avoid collisions
      if (actualDaysAhead != daysAhead) {
        // Extract timeIndex from original ID and recalculate with new day
        final timeIndex = id % 100;
        actualId = _baseNotificationId + (actualDaysAhead * 100) + timeIndex;
        debugPrint(
          '>> [DEBUG] Time $hour:$minute pushed from day $daysAhead to day $actualDaysAhead, ID changed from $id to $actualId',
        );
      }

      debugPrint(
        '>> [DEBUG] SUCCESS: ZonedSchedule ID $actualId set for EXACTLY: $scheduledDate (Verse ID: ${verse.number})',
      );

      await _notifications.zonedSchedule(
        actualId,
        'آيات - Ayaat',
        verse.text,
        scheduledDate,
        NotificationDetails(
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: verse.number.toString(),
      );
    } catch (e) {
      debugPrint('Error scheduling notification $actualId: $e');
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
}
