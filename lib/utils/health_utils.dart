import 'dart:math' as math;

/// Heart rate zone classification and health-related utility functions.
class HealthUtils {
  static String classifyBpm(int bpm, int age) {
    if (bpm < 50) return 'Very Low';
    if (bpm < 60) return 'Low';
    if (bpm <= getUpperRestingLimit(age)) return 'Normal';
    if (bpm <= 100) return 'Elevated';
    if (bpm <= 120) return 'High';
    return 'Very High';
  }

  static int getUpperRestingLimit(int age) {
    if (age < 10) return 100;
    if (age < 18) return 90;
    return 80;
  }

  static int maxHeartRate(int age) => 220 - age;

  static Map<String, List<int>> getZoneRanges(int age) {
    final max = maxHeartRate(age);
    return {
      'Rest': [0, (max * 0.50).round()],
      'Warm Up': [(max * 0.50).round() + 1, (max * 0.60).round()],
      'Fat Burn': [(max * 0.60).round() + 1, (max * 0.70).round()],
      'Cardio': [(max * 0.70).round() + 1, (max * 0.80).round()],
      'Peak': [(max * 0.80).round() + 1, (max * 0.90).round()],
      'Max': [(max * 0.90).round() + 1, max],
    };
  }

  static String currentZone(int bpm, int age) {
    final zones = getZoneRanges(age);
    for (final entry in zones.entries) {
      if (bpm >= entry.value[0] && bpm <= entry.value[1]) {
        return entry.key;
      }
    }
    return 'Unknown';
  }

  static String spo2Status(int spo2) {
    if (spo2 >= 95) return 'Normal';
    if (spo2 >= 90) return 'Low';
    return 'Critical';
  }

  /// Rough RMSSD-based HRV estimate from consecutive BPM differences.
  static double hrvValue(List<int> recentBpm) {
    if (recentBpm.length < 3) return 0;
    final deltas = <double>[];
    for (var i = 1; i < recentBpm.length; i++) {
      deltas.add((recentBpm[i] - recentBpm[i - 1]).abs().toDouble());
    }
    final mean = deltas.reduce((a, b) => a + b) / deltas.length;
    final variance =
        deltas.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
            deltas.length;
    return variance > 0
        ? double.parse(math.sqrt(variance).toStringAsFixed(1))
        : 0;
  }

  static String recoveryScore(int avgRestingBpm) {
    if (avgRestingBpm < 60) return 'Excellent';
    if (avgRestingBpm < 70) return 'Good';
    if (avgRestingBpm < 80) return 'Fair';
    return 'Needs Attention';
  }
}
