/// A recorded session of heart rate measurements.
class Session {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final List<int> bpmReadings;
  final List<int> spo2Readings;

  Session({
    required this.id,
    required this.startTime,
    this.endTime,
    List<int>? bpmReadings,
    List<int>? spo2Readings,
  })  : bpmReadings = bpmReadings ?? [],
        spo2Readings = spo2Readings ?? [];

  int get avgBpm => bpmReadings.isEmpty
      ? 0
      : (bpmReadings.reduce((a, b) => a + b) / bpmReadings.length).round();

  int get maxBpm =>
      bpmReadings.isEmpty ? 0 : bpmReadings.reduce((a, b) => a > b ? a : b);

  int get minBpm =>
      bpmReadings.isEmpty ? 0 : bpmReadings.reduce((a, b) => a < b ? a : b);

  int get avgSpo2 => spo2Readings.isEmpty
      ? 0
      : (spo2Readings.reduce((a, b) => a + b) / spo2Readings.length).round();

  Duration get duration => endTime != null
      ? endTime!.difference(startTime)
      : DateTime.now().difference(startTime);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'bpmReadings': bpmReadings,
      'spo2Readings': spo2Readings,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int)
          : null,
      bpmReadings: List<int>.from(map['bpmReadings'] as List? ?? []),
      spo2Readings: List<int>.from(map['spo2Readings'] as List? ?? []),
    );
  }
}
