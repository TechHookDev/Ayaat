import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() async {
  final baseUrl = 'https://api.alquran.cloud/v1/ayah';
  final random = Random();
  int successCount = 0;
  
  print('Starting batch fetch...');
  final startTime = DateTime.now();
  
  try {
    for (int i = 0; i < 5; i++) {
      final futures = <Future<http.Response>>[];
      for (int j = 0; j < 7; j++) {
        final ayahNum = random.nextInt(6236) + 1;
        futures.add(http.get(Uri.parse(baseUrl + '/' + ayahNum.toString() + '/en.sahih')));
      }
      
      final responses = await Future.wait(futures);
      for (var r in responses) {
        if (r.statusCode == 200) successCount++;
        else print('Error: ' + r.statusCode.toString());
      }
      
      print('Batch ' + (i+1).toString() + ' complete. Scheduled so far: ' + successCount.toString() + '. Delaying...');
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  } catch(e) {
    print('Exception: ' + e.toString());
  }
  
  final elapsed = DateTime.now().difference(startTime);
  print('Total success: ' + successCount.toString() + ' in ' + elapsed.inMilliseconds.toString() + 'ms');
}
