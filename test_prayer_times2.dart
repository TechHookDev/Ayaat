import 'package:adhan/adhan.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/standalone.dart' as tz;

void main() {
  tz_data.initializeTimeZones();
  // Set local timezone to America/New_York (EST)
  tz.setLocalLocation(tz.getLocation('America/New_York'));
  
  // Use mock coordinates for New York
  final myCoordinates = Coordinates(40.7128, -74.0060);
  final params = CalculationMethod.muslim_world_league.getParameters();
  params.madhab = Madhab.shafi;

  for (int day = 0; day < 2; day++) {
    final targetDate = DateTime.now().add(Duration(days: day));
    final dateComponents = DateComponents(targetDate.year, targetDate.month, targetDate.day);
    final dailyPrayerTimes = PrayerTimes(myCoordinates, dateComponents, params);
    
    print('--- Day \$day: \$targetDate ---');
    print('Fajr: \${dailyPrayerTimes.fajr.toLocal()} -> +30m: \${dailyPrayerTimes.fajr.toLocal().add(Duration(minutes: 30))}');
    print('Dhuhr: \${dailyPrayerTimes.dhuhr.toLocal()} -> +30m: \${dailyPrayerTimes.dhuhr.toLocal().add(Duration(minutes: 30))}');
    print('Asr: \${dailyPrayerTimes.asr.toLocal()} -> +30m: \${dailyPrayerTimes.asr.toLocal().add(Duration(minutes: 30))}');
    print('Maghrib: \${dailyPrayerTimes.maghrib.toLocal()} -> +30m: \${dailyPrayerTimes.maghrib.toLocal().add(Duration(minutes: 30))}');
    print('Isha: \${dailyPrayerTimes.isha.toLocal()} -> +30m: \${dailyPrayerTimes.isha.toLocal().add(Duration(minutes: 30))}');
  }
}
