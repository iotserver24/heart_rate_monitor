import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';

/// Device connection screen for pairing with an ESP32 sensor via BLE.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const _accent = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Connect Device'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _bleSection(ble),
      ),
    );
  }

  Widget _bleSection(BleService ble) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ESP32 Devices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (ble.isScanning)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_accent),
                ),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: ble.isScanning ? null : () => ble.startScan(),
              child: Text(
                ble.isScanning ? 'Scanning...' : 'Rescan',
                style: const TextStyle(color: _accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ble.state == BleConnectionState.error && ble.errorMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              ble.errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (ble.foundDevices.isEmpty && !ble.isScanning)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 48,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No devices found',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Make sure your ESP32 is powered on and in range',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ...ble.foundDevices.map((device) {
          final isConnecting = ble.state == BleConnectionState.connecting;
          final isSelected = ble.state == BleConnectionState.connected;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4CAF50).withOpacity(0.5)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  color: _accent,
                  size: 20,
                ),
              ),
              title: Text(
                device.platformName.isNotEmpty
                    ? device.platformName
                    : 'Unknown Device',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                device.id.id,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
              trailing: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    )
                  : isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                      : const Icon(Icons.chevron_right, color: Colors.white30),
              onTap: isConnecting || isSelected
                  ? null
                  : () async {
                      final success = await ble.connect(device);
                      if (success && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
            ),
          );
        }),
        const SizedBox(height: 24),
        _deviceIdInfo(),
      ],
    );
  }

  Widget _deviceIdInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESP32 BLE Setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ESP32 should advertise a BLE service with heart rate, '
            'SpO2, and temperature characteristics. See the included Arduino '
            'sketch for the firmware to flash.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
