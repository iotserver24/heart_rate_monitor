import 'package:flutter/material.dart';
import '../utils/health_utils.dart';

/// Educational screen with heart rate health information, zones, tips, and insights.
class HealthInfoScreen extends StatelessWidget {
  const HealthInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final zones = HealthUtils.getZoneRanges(25);
    final maxHr = HealthUtils.maxHeartRate(25);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Health Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            icon: Icons.favorite,
            iconColor: const Color(0xFFE53935),
            title: 'Normal Resting Heart Rate',
            children: [
              _bulletRow('Adults (18+): 60-80 BPM'),
              _bulletRow('Teens (12-18): 60-90 BPM'),
              _bulletRow('Children (6-12): 70-110 BPM'),
              _bulletRow('Athletes: 40-60 BPM (lower is normal)'),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.show_chart,
            iconColor: const Color(0xFF29B6F6),
            title: 'Heart Rate Zones',
            children: [
              _bulletRow('Max HR formula: 220 - age = $maxHr BPM',
                  bold: true),
              const SizedBox(height: 8),
              ...zones.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _zoneColor(e.key),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${e.key}: ${e.value[0]}-${e.value[1]} BPM',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.water_drop,
            iconColor: const Color(0xFF42A5F5),
            title: 'SpO2 (Blood Oxygen)',
            children: [
              _bulletRow('95-100%: Normal range'),
              _bulletRow('90-94%: Slightly low, monitor closely'),
              _bulletRow('Below 90%: Seek medical attention'),
              _bulletRow('SpO2 measures oxygen saturation in blood'),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.thermostat,
            iconColor: const Color(0xFFFF7043),
            title: 'Body Temperature',
            children: [
              _bulletRow('Normal: 36.1 - 37.2 C'),
              _bulletRow('Low grade fever: 37.3 - 38.0 C'),
              _bulletRow('Fever: 38.0+ C'),
              _bulletRow('Hypothermia: below 35.0 C'),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.monitor_heart,
            iconColor: const Color(0xFFAB47BC),
            title: 'HRV (Heart Rate Variability)',
            children: [
              _bulletRow('Measures variation between heart beats'),
              _bulletRow('Higher HRV = better cardiovascular fitness',
                  bold: true),
              _bulletRow('Stress, poor sleep lower HRV'),
              _bulletRow('Regular exercise improves HRV over time'),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.tips_and_updates,
            iconColor: const Color(0xFF66BB6A),
            title: 'Tips for a Healthy Heart',
            children: [
              _bulletRow('Exercise 150 min/week (moderate intensity)'),
              _bulletRow('Aim for 7-9 hours of quality sleep'),
              _bulletRow('Manage stress through meditation or breathing'),
              _bulletRow('Limit caffeine and alcohol intake'),
              _bulletRow('Maintain a balanced, low-sodium diet'),
              _bulletRow('Stay hydrated throughout the day'),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFFF9800),
            title: 'When to Seek Help',
            children: [
              _bulletRow('Resting HR consistently over 100 (tachycardia)',
                  bold: true),
              _bulletRow('Resting HR consistently below 50 (bradycardia)',
                  bold: true),
              _bulletRow('Irregular or pounding heartbeat'),
              _bulletRow('Chest pain, dizziness, or shortness of breath'),
              _bulletRow('These insights are not a substitute for medical advice'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'This app provides general health information for educational purposes only. '
            'Always consult a healthcare professional for medical advice.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _bulletRow(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE53935),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: bold ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Rest':
        return const Color(0xFF4CAF50);
      case 'Warm Up':
        return const Color(0xFF8BC34A);
      case 'Fat Burn':
        return const Color(0xFFFFEB3B);
      case 'Cardio':
        return const Color(0xFFFF9800);
      case 'Peak':
        return const Color(0xFFFF5722);
      case 'Max':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }
}
