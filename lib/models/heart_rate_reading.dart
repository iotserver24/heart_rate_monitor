/// Heart rate measurement data point.
class HeartRateReading {
  final DateTime timestamp;
  final int bpm;
  final int? spo2;
  final double? temperature;

  HeartRateReading({
    required this.timestamp,
    required this.bpm,
    this.spo2,
    this.temperature,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'bpm': bpm,
      'spo2': spo2,
      'temperature': temperature,
    };
  }

  factory HeartRateReading.fromMap(Map<String, dynamic> map) {
    return HeartRateReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      bpm: map['bpm'] as int,
      spo2: map['spo2'] as int?,
      temperature: (map['temperature'] as num?)?.toDouble(),
    );
  }
}
