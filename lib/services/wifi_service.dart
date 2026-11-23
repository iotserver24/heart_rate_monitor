import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/heart_rate_reading.dart';

/// Fallback WiFi-based connection to ESP32 HTTP server.
/// ESP32 should serve JSON at http://<ip>/heartRate with fields: bpm, spo2, temp
class WifiService extends ChangeNotifier {
  String? _ipAddress;
  int _port = 80;
  double _pollIntervalSeconds = 1.0;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  int _currentBpm = 0;
  int get currentBpm => _currentBpm;

  int _currentSpo2 = 0;
  int get currentSpo2 => _currentSpo2;

  double _currentTemp = 0;
  double get currentTemp => _currentTemp;

  final List<HeartRateReading> _liveReadings = [];
  List<HeartRateReading> get liveReadings => List.unmodifiable(_liveReadings);

  Timer? _pollTimer;

  final _bpmController = StreamController<int>.broadcast();
  Stream<int> get bpmStream => _bpmController.stream;

  final _readingController =
      StreamController<HeartRateReading>.broadcast();
  Stream<HeartRateReading> get readingStream => _readingController.stream;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void configure({required String ip, int port = 80, double interval = 1.0}) {
    _ipAddress = ip;
    _port = port;
    _pollIntervalSeconds = interval;
  }

  Future<bool> connect() async {
    if (_ipAddress == null) {
      _errorMessage = 'IP address not set';
      notifyListeners();
      return false;
    }
    try {
      // Test connection with one poll
      final success = await _poll();
      if (success) {
        _isConnected = true;
        _startPolling();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'WiFi connection failed: $e';
      notifyListeners();
      return false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: (_pollIntervalSeconds * 1000).round()),
      (_) => _poll(),
    );
  }

  Future<bool> _poll() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_ipAddress:$_port/heartRate'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _currentBpm = (data['bpm'] ?? 0) as int? ?? 0;
        _currentSpo2 = (data['spo2'] ?? 0) as int? ?? 0;
        _currentTemp = (data['temp'] as num?)?.toDouble() ?? 0;

        final reading = HeartRateReading(
          timestamp: DateTime.now(),
          bpm: _currentBpm,
          spo2: _currentSpo2 > 0 ? _currentSpo2 : null,
          temperature: _currentTemp > 0 ? _currentTemp : null,
        );
        _liveReadings.add(reading);
        if (_liveReadings.length > 300) {
          _liveReadings.removeAt(0);
        }
        _bpmController.add(_currentBpm);
        _readingController.add(reading);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Poll error: $e';
      return false;
    }
  }

  void clearLiveReadings() {
    _liveReadings.clear();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _isConnected = false;
    _currentBpm = 0;
    _currentSpo2 = 0;
    _currentTemp = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bpmController.close();
    _readingController.close();
    super.dispose();
  }
}
