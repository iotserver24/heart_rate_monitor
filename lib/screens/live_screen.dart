import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ble_service.dart';
import '../utils/health_utils.dart';
import '../widgets/pulse_heart.dart';
import '../widgets/gauge_ring.dart';
import '../widgets/heart_rate_chart.dart';
import '../widgets/zone_indicator.dart';
import '../utils/session_storage.dart';
import '../models/session.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  Session? _currentSession;
  Timer? _sessionTimer;
  bool _sessionActive = false;

  void _startListening() {
    final ble = context.read<BleService>();
    ble.readingStream.listen((reading) {
      if (_sessionActive && _currentSession != null) {
        _currentSession!.bpmReadings.add(reading.bpm);
        if (reading.spo2 != null) {
          _currentSession!.spo2Readings.add(reading.spo2!);
        }
      }
    });
  }

  void _startSession() {
    setState(() {
      _sessionActive = true;
      _currentSession = Session(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
      );
    });
  }

  void _stopSession() async {
    if (_currentSession != null) {
      _currentSession!.endTime = DateTime.now();
      await SessionStorage.saveSession(_currentSession!);
    }
    setState(() {
      _sessionActive = false;
      _currentSession = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session saved!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final connected = ble.state == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Live Monitor'),
        actions: [
          _connectionIndicator(connected),
          const SizedBox(width: 16),
        ],
      ),
      body: connected ? _connectedView(ble) : _disconnectedView(),
      floatingActionButton: connected
          ? FloatingActionButton.extended(
              onPressed: _sessionActive ? _stopSession : _startSession,
              backgroundColor:
                  _sessionActive ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
              icon: Icon(_sessionActive ? Icons.stop : Icons.play_arrow),
              label: Text(_sessionActive ? 'Stop Session' : 'Start Session'),
            )
          : null,
    );
  }

  Widget _connectionIndicator(bool connected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? const Color(0xFF4CAF50) : Colors.grey,
            boxShadow: connected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          connected ? 'Connected' : 'Disconnected',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _disconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PulseHeart(bpm: 0, size: 100),
          const SizedBox(height: 24),
          const Text(
            'Not Connected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to your ESP32 sensor to start monitoring',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showConnectDialog(),
            icon: const Icon(Icons.bluetooth),
            label: const Text('Connect Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectDialog() {
    Navigator.pushNamed(context, '/connect');
  }

  Widget _connectedView(BleService ble) {
    final readings = ble.liveReadings;
    final chartPoints = <FlSpot>[];
    for (var i = 0; i < readings.length; i++) {
      chartPoints.add(FlSpot(i.toDouble(), readings[i].bpm.toDouble()));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main BPM display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F3A), Color(0xFF0A0E21)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                PulseHeart(
                  bpm: ble.currentBpm,
                  size: 60,
                  color: _bpmColor(ble.currentBpm),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      ble.currentBpm > 0 ? '${ble.currentBpm}' : '--',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ble.currentBpm > 0
                      ? HealthUtils.classifyBpm(ble.currentBpm, 25)
                      : 'Waiting for data...',
                  style: TextStyle(
                    color: _bpmColor(ble.currentBpm),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Zone indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ZoneIndicator(bpm: ble.currentBpm, age: 25),
          ),
          const SizedBox(height: 12),
          // SpO2 and Temperature gauges
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      GaugeRing(
                        value: ble.currentSpo2,
                        maxValue: 100,
                        label: 'SpO2',
                        color: const Color(0xFF29B6F6),
                        size: 100,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        HealthUtils.spo2Status(ble.currentSpo2),
                        style: TextStyle(
                          color: ble.currentSpo2 >= 95
                              ? const Color(0xFF4CAF50)
                              : ble.currentSpo2 >= 90
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFFE53935),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      GaugeRing(
                        value: ble.currentTemp > 0
                            ? (ble.currentTemp * 10).round()
                            : 0,
                        maxValue: 450,
                        label: '°C',
                        color: const Color(0xFFFF7043),
                        size: 100,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ble.currentTemp > 0
                            ? '${ble.currentTemp.toStringAsFixed(1)} °C'
                            : '-- °C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Chart
          Container(
            height: 200,
            padding: const EdgeInsets.only(
              top: 16,
              left: 8,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live BPM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: HeartRateChart(dataPoints: chartPoints),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Quick stats
          if (readings.length >= 2) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F3A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickStat('Min',
                      '${readings.map((r) => r.bpm).reduce((a, b) => a < b ? a : b)}'),
                  _quickStat('Max',
                      '${readings.map((r) => r.bpm).reduce((a, b) => a > b ? a : b)}'),
                  _quickStat('Avg',
                      '${(readings.map((r) => r.bpm).reduce((a, b) => a + b) ~/ readings.length)}'),
                  _quickStat(
                      'HRV',
                      HealthUtils.hrvValue(
                              readings.map((r) => r.bpm).toList())
                          .toString()),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Color _bpmColor(int bpm) {
    if (bpm == 0) return Colors.grey;
    if (bpm < 60) return Colors.orange;
    if (bpm <= 100) return const Color(0xFF4CAF50);
    if (bpm <= 140) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }
}
