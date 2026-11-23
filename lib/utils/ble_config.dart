/// BLE configuration constants for ESP32 heart rate sensor.
class BleConfig {
  // ESP32 default service UUID for heart rate data
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String heartRateCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String spo2CharUuid = 'beb5483f-36e1-4688-b7f5-ea07361b26a8';
  static const String tempCharUuid = 'beb54840-36e1-4688-b7f5-ea07361b26a8';

  // ESP32 device name prefix to filter scan results
  static const String deviceNamePrefix = 'ESP32';
}
