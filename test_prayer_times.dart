import 'package:adhan/adhan.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/standalone.dart' as tz;

void main() {
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/New_York'));
  final myCoordinates = Coordinates(40.7128, -74.0060);
  final params = CalculationMethod.muslim_world_league.getParameters();
  params.madhab = Madhab.shafi;

  for (int day = 0; day < 2; day++) {
    final targetDate = DateTime.now().add(Duration(days: day));
    final dateComponents = DateComponents(targetDate.year, targetDate.month, targetDate.day);
    final dailyPrayerTimes = PrayerTimes(myCoordinates, dateComponents, params);
    
    print('--- Day ${day}: ${targetDate} ---');
    print('Isha: ${dailyPrayerTimes.isha.toLocal()} -> +30m: ${dailyPrayerTimes.isha.toLocal().add(Duration(minutes: 30))}');
  }
}
