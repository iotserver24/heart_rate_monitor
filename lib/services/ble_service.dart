import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/heart_rate_reading.dart';
import '../utils/ble_config.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected, error }

/// Manages BLE connection to ESP32 and streams heart rate data.
class BleService extends ChangeNotifier {
  BluetoothDevice? _device;
  StreamSubscription? _scanSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _hrSub;
  StreamSubscription? _spo2Sub;
  StreamSubscription? _tempSub;
  StreamSubscription? _connectionSub;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  int _currentBpm = 0;
  int get currentBpm => _currentBpm;

  int _currentSpo2 = 0;
  int get currentSpo2 => _currentSpo2;

  double _currentTemp = 0;
  double get currentTemp => _currentTemp;

  final List<HeartRateReading> _liveReadings = [];
  List<HeartRateReading> get liveReadings => List.unmodifiable(_liveReadings);

  final List<BluetoothDevice> _foundDevices = [];
  List<BluetoothDevice> get foundDevices => List.unmodifiable(_foundDevices);

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  final _bpmController = StreamController<int>.broadcast();
  Stream<int> get bpmStream => _bpmController.stream;

  final _readingController =
      StreamController<HeartRateReading>.broadcast();
  Stream<HeartRateReading> get readingStream => _readingController.stream;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Start scanning for ESP32 BLE devices.
  Future<void> startScan() async {
    if (_isScanning) return;
    _foundDevices.clear();
    _state = BleConnectionState.scanning;
    _errorMessage = '';
    _isScanning = true;
    notifyListeners();

    try {
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName.isNotEmpty &&
              (r.device.platformName
                  .startsWith(BleConfig.deviceNamePrefix) ||
                  r.device.platformName.toLowerCase().contains('esp32'))) {
            if (!_foundDevices.contains(r.device)) {
              _foundDevices.add(r.device);
              notifyListeners();
            }
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _isScanning = false;
      if (_state == BleConnectionState.scanning) {
        _state = _foundDevices.isEmpty
            ? BleConnectionState.disconnected
            : BleConnectionState.disconnected;
      }
      notifyListeners();
    } catch (e) {
      _isScanning = false;
      _state = BleConnectionState.error;
      _errorMessage = 'Scan failed: $e';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  /// Connect to a specific ESP32 device.
  Future<bool> connect(BluetoothDevice device) async {
    _state = BleConnectionState.connecting;
    _errorMessage = '';
    notifyListeners();

    try {
      await FlutterBluePlus.stopScan();
      await device.connect(timeout: const Duration(seconds: 15));
      _device = device;

      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      await _discoverAndSubscribe(device);
      _state = BleConnectionState.connected;
      notifyListeners();
      return true;
    } catch (e) {
      _state = BleConnectionState.error;
      _errorMessage = 'Connection failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BleConfig.serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == BleConfig.heartRateCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _hrSub = char.onValueReceived.listen((value) {
              _parseHeartRateData(value);
            });
          } else if (uuid == BleConfig.spo2CharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _spo2Sub = char.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                _currentSpo2 = value[0];
                notifyListeners();
              }
            });
          } else if (uuid == BleConfig.tempCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _tempSub = char.onValueReceived.listen((value) {
              if (value.length >= 4) {
                _currentTemp =
                    (value[0] | (value[1] << 8)) / 100.0;
                notifyListeners();
              }
            });
          }
        }
      }
    }
  }

  void _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return;

    // Check if data is a JSON string (ESP32 sending JSON)
    try {
      final jsonString = String.fromCharCodes(data);
      if (jsonString.trim().startsWith('{')) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final bpm = (json['bpm'] ?? json['heart_rate'] ?? 0) as int? ?? 0;
        final spo2 = json['spo2'] as int?;
        final temp = (json['temp'] ?? json['temperature']) as num?;

        _currentBpm = bpm;
        if (spo2 != null) _currentSpo2 = spo2;
        if (temp != null) _currentTemp = temp.toDouble();

        final reading = HeartRateReading(
          timestamp: DateTime.now(),
          bpm: bpm,
          spo2: spo2,
          temperature: temp?.toDouble(),
        );
        _addReading(reading);
        return;
      }
    } catch (_) {
      // Not JSON, fall through to binary parsing
    }

    // Binary parsing: first byte = BPM
    _currentBpm = data[0];
    if (data.length >= 2) _currentSpo2 = data[1];
    if (data.length >= 4) {
      _currentTemp = (data[2] | (data[3] << 8)) / 100.0;
    }

    final reading = HeartRateReading(
      timestamp: DateTime.now(),
      bpm: _currentBpm,
      spo2: _currentSpo2 > 0 ? _currentSpo2 : null,
      temperature: _currentTemp > 0 ? _currentTemp : null,
    );
    _addReading(reading);
  }

  void _addReading(HeartRateReading reading) {
    _liveReadings.add(reading);
    if (_liveReadings.length > 300) {
      _liveReadings.removeAt(0);
    }
    _bpmController.add(reading.bpm);
    _readingController.add(reading);
    notifyListeners();
  }

  /// Clear live readings (used when starting a new session).
  void clearLiveReadings() {
    _liveReadings.clear();
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _hrSub?.cancel();
    await _spo2Sub?.cancel();
    await _tempSub?.cancel();
    await _connectionSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _state = BleConnectionState.disconnected;
    _currentBpm = 0;
    _currentSpo2 = 0;
    _currentTemp = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _stateSub?.cancel();
    _hrSub?.cancel();
    _spo2Sub?.cancel();
    _tempSub?.cancel();
    _connectionSub?.cancel();
    _bpmController.close();
    _readingController.close();
    super.dispose();
  }
}
