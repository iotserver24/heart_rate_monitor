# Heart Rate Monitor

A Flutter mobile app that connects to an ESP32 with a MAX30102 sensor over **Bluetooth Low Energy (BLE)** or **WiFi**, displaying live heart rate, SpO2, temperature, session history, stats, and health insights.

## Features

- **Live Monitoring**: Real-time BPM with animated pulsing heart, live scrolling chart
- **SpO2 & Temperature**: Blood oxygen saturation and body temperature gauges
- **Heart Rate Zones**: Color-coded zones (Rest, Warm Up, Fat Burn, Cardio, Peak, Max)
- **Session Recording**: Start/stop sessions, save to local storage, review later
- **Statistics**: Overall summary (avg/max/min BPM, recovery score), per-session charts
- **Health Info**: Educational content on HR, SpO2, temperature, HRV, healthy habits
- **Dual Connection**: BLE (preferred) or WiFi fallback
- **Dark UI**: Polished dark theme designed for health/medical apps
- **Small Size**: Minimal dependencies, ProGuard/R8 enabled for release builds

## Screens

| Screen | Description |
|--------|------------|
| Live | Real-time BPM, SpO2, temp, chart, zone indicator, session start/stop |
| Stats | Overall summary card + expandable session history with mini charts |
| Health | Normal ranges, HR zones, SpO2 info, HRV, tips, warning signs |
| Connect | BLE scan + device list, or WiFi IP/port configuration |

## Building

### Prerequisites
- Flutter SDK 3.0+ (install from https://docs.flutter.dev)
- Android Studio or Xcode for the platform toolchain

### Steps
```bash
cd heart_rate_monitor
flutter pub get
flutter run                    # debug (connected device/emulator)
flutter build apk --release    # release APK (~4-6 MB with R8)
flutter build appbundle --release  # Play Store AAB
```

### App Size Optimization
- R8/ProGuard enabled in `android/app/build.gradle` (`minifyEnabled`, `shrinkResources`)
- Only essential dependencies, no heavy UI frameworks
- `--split-per-abi` for smaller per-architecture APKs:
  ```bash
  flutter build apk --release --split-per-abi
  ```

## ESP32 Firmware

Three sketches are included in `esp32_firmware/`.

### ESP32-C6 + analog pulse sensor: `esp32_c6_heart_rate_ble/` (verified)
This is the sketch that has been compiled, flashed, and tested against a real
ESP32-C6. It targets a **3-wire analog pulse sensor** (the round "Pulse Sensor"
style module), not a MAX30102.

- Advertises as `ESP32-C6 HRM` with the app's service UUID
- Samples the sensor waveform at 500 Hz and publishes `{"bpm":72}` via BLE notify
  once a second (11 bytes, fits a single ATT packet at the default MTU of 23)
- Rejects noise: a floating pin, a rail-sitting pin, or an erratic rhythm reports
  `0` BPM instead of a false rate
- **Heart rate only.** An analog pulse module cannot measure SpO2 or body
  temperature, so the SpO2/temp characteristics are created but never written.
  The app shows 0 % and `-- °C` for those two gauges.
- Requires ESP32 Arduino core **4.0.0+** (uses the new `BLE.h` API)

Build and flash:
```bash
arduino-cli compile --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc \
  --build-path /tmp/c6build esp32_firmware/esp32_c6_heart_rate_ble

arduino-cli upload -p /dev/ttyACM0 \
  --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc \
  --build-path /tmp/c6build esp32_firmware/esp32_c6_heart_rate_ble
```

`CDCOnBoot=cdc` is required for Serial output to appear over the USB connector.
The default sends `Serial` to UART0 pins and the monitor stays silent.

Wiring:

| Pulse sensor | ESP32-C6 |
|---|---|
| VCC (red) | 3V3 |
| GND | GND |
| SIGNAL | GPIO2 |

Only GPIO0–GPIO6 are ADC-capable on the C6, so the signal wire must use one of
those. Override the default with `-DPULSE_SIGNAL_PIN=<n>`:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32c6:CDCOnBoot=cdc \
  --build-extra-flags "-DPULSE_SIGNAL_PIN=3" esp32_firmware/esp32_c6_heart_rate_ble
```

Watch the serial log at 115200 baud to confirm the sensor is wired correctly.
`lead_off=1` and a baseline outside roughly 900–2600 mV mean the signal wire is
not connected.

### BLE (MAX30102): `esp32_heart_rate_ble.ino`
- For a classic ESP32 with a MAX30102 pulse oximeter on I2C
- Advertises as `ESP32_HRMonitor`
- Intended to send JSON `{"bpm":72,"spo2":97,"temp":36.5}` via BLE notify
- Note: this sketch targets the pre-4.0 `BLEDevice.h` API and does not build
  against ESP32 core 4.x, or for the C6 (no Bluedroid). It also never registers
  its server callbacks, so it stays silent until that is fixed.

### WiFi fallback: `esp32_heart_rate_wifi.ino`
- ESP32 runs HTTP server on port 80
- `GET /heartRate` returns JSON heart rate data
- Edit `ssid` and `password` in the sketch, upload, check Serial Monitor for IP
- Enter IP in the app's WiFi connection tab

### Hardware
- ESP32-C6 dev board (verified), or a classic ESP32 for the MAX30102 sketches
- 3-wire analog pulse sensor for the C6 sketch
- MAX30102 pulse oximeter (I2C: SDA=GPIO21, SCL=GPIO22 on classic ESP32)
- Optional: MLX90614 for body temperature


## Project Structure
```
heart_rate_monitor/
├── lib/
│   ├── main.dart              # App entry, theme, navigation
│   ├── models/
│   │   ├── heart_rate_reading.dart
│   │   └── session.dart
│   ├── services/
│   │   ├── ble_service.dart    # BLE connection + data stream
│   │   └── wifi_service.dart   # WiFi fallback connection
│   ├── screens/
│   │   ├── live_screen.dart    # Live monitoring
│   │   ├── stats_screen.dart   # History & stats
│   │   ├── health_info_screen.dart
│   │   └── connect_screen.dart
│   ├── widgets/
│   │   ├── pulse_heart.dart    # Animated beating heart
│   │   ├── heart_rate_chart.dart  # fl_chart line chart
│   │   ├── gauge_ring.dart     # Circular progress gauge
│   │   └── zone_indicator.dart # HR zone bar
│   └── utils/
│       ├── ble_config.dart
│       ├── health_utils.dart
│       └── session_storage.dart
├── android/
├── test/
├── esp32_firmware/
│   ├── esp32_c6_heart_rate_ble/
│   │   └── esp32_c6_heart_rate_ble.ino
│   ├── esp32_heart_rate_ble.ino
│   └── esp32_heart_rate_wifi.ino
└── pubspec.yaml
```

## BLE UUID Configuration
The app looks for these UUIDs (defined in `lib/utils/ble_config.dart`). Match them in your ESP32 firmware:
- Service: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Heart Rate: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- SpO2: `beb5483f-36e1-4688-b7f5-ea07361b26a8`
- Temperature: `beb54840-36e1-4688-b7f5-ea07361b26a8`

## Testing
```bash
flutter test
```
