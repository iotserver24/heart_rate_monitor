import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import '../services/wifi_service.dart';

/// Device connection screen for pairing with ESP32 via BLE or WiFi.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  ConnectionMode _mode = ConnectionMode.ble;
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '80');

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Connect Device'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeSelector(),
            const SizedBox(height: 20),
            if (_mode == ConnectionMode.ble) ...[
              _bleSection(ble),
            ] else ...[
              _wifiSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = ConnectionMode.ble),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _mode == ConnectionMode.ble
                      ? const Color(0xFFE53935)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 18,
                      color: _mode == ConnectionMode.ble
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Bluetooth',
                      style: TextStyle(
                        color: _mode == ConnectionMode.ble
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = ConnectionMode.wifi),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _mode == ConnectionMode.wifi
                      ? const Color(0xFF29B6F6)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 18,
                      color: _mode == ConnectionMode.wifi
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'WiFi',
                      style: TextStyle(
                        color: _mode == ConnectionMode.wifi
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: ble.isScanning ? null : () => ble.startScan(),
              child: Text(
                ble.isScanning ? 'Scanning...' : 'Rescan',
                style: const TextStyle(color: Color(0xFFE53935)),
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
          final isConnecting =
              ble.state == BleConnectionState.connecting;
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
                  color: const Color(0xFFE53935).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  color: Color(0xFFE53935),
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
                        color: Color(0xFFE53935),
                      ),
                    )
                  : isSelected
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF4CAF50))
                      : const Icon(Icons.chevron_right,
                          color: Colors.white30),
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

  Widget _wifiSection() {
    final wifi = context.read<WifiService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WiFi Connection',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to ESP32 over WiFi. ESP32 should run an HTTP server '
          'serving JSON data at /heartRate.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        _inputField(
          controller: _ipController,
          label: 'ESP32 IP Address',
          icon: Icons.router,
        ),
        const SizedBox(height: 12),
        _inputField(
          controller: _portController,
          label: 'Port',
          icon: Icons.numbers,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              wifi.configure(
                ip: _ipController.text.trim(),
                port: int.tryParse(_portController.text.trim()) ?? 80,
              );
              final success = await wifi.connect();
              if (success && context.mounted) {
                Navigator.pop(context);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(wifi.errorMessage),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.wifi),
            label: const Text('Connect via WiFi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF29B6F6),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF29B6F6)),
        filled: true,
        fillColor: const Color(0xFF1A1F3A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF29B6F6)),
        ),
      ),
    );
  }
}

enum ConnectionMode { ble, wifi }
