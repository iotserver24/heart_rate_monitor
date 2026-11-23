import 'package:flutter_test/flutter_test.dart';
import 'package:heart_rate_monitor/utils/health_utils.dart';

void main() {
  group('HealthUtils', () {
    test('maxHeartRate is 220 minus age', () {
      expect(HealthUtils.maxHeartRate(25), 195);
      expect(HealthUtils.maxHeartRate(50), 170);
    });

    test('classifyBpm returns correct category', () {
      expect(HealthUtils.classifyBpm(55, 25), 'Low');
      expect(HealthUtils.classifyBpm(72, 25), 'Normal');
      expect(HealthUtils.classifyBpm(95, 25), 'Elevated');
      expect(HealthUtils.classifyBpm(115, 25), 'High');
      expect(HealthUtils.classifyBpm(180, 25), 'Very High');
    });

    test('spo2Status returns correct status', () {
      expect(HealthUtils.spo2Status(98), 'Normal');
      expect(HealthUtils.spo2Status(92), 'Low');
      expect(HealthUtils.spo2Status(85), 'Critical');
    });

    test('currentZone returns correct zone name', () {
      final zone = HealthUtils.currentZone(72, 25);
      expect(zone, isNotEmpty);
    });

    test('recoveryScore returns correct assessment', () {
      expect(HealthUtils.recoveryScore(55), 'Excellent');
      expect(HealthUtils.recoveryScore(65), 'Good');
      expect(HealthUtils.recoveryScore(75), 'Fair');
      expect(HealthUtils.recoveryScore(85), 'Needs Attention');
    });

    test('hrvValue returns 0 for insufficient data', () {
      expect(HealthUtils.hrvValue([72, 73]), 0);
    });

    test('hrvValue returns positive value for varied data', () {
      final hrv = HealthUtils.hrvValue([72, 80, 68, 75, 70, 78]);
      expect(hrv, greaterThan(0));
    });

    test('getZoneRanges returns 6 zones', () {
      final zones = HealthUtils.getZoneRanges(25);
      expect(zones.length, 6);
      expect(zones.containsKey('Rest'), isTrue);
      expect(zones.containsKey('Max'), isTrue);
    });
  });
}
