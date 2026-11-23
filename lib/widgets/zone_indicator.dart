import 'package:flutter/material.dart';
import '../utils/health_utils.dart';

/// Displays the current heart rate zone as a colored horizontal bar.
class ZoneIndicator extends StatelessWidget {
  final int bpm;
  final int age;

  const ZoneIndicator({
    super.key,
    required this.bpm,
    this.age = 25,
  });

  static const _zones = [
    ('Rest', Color(0xFF4CAF50)),
    ('Warm Up', Color(0xFF8BC34A)),
    ('Fat Burn', Color(0xFFFFEB3B)),
    ('Cardio', Color(0xFFFF9800)),
    ('Peak', Color(0xFFFF5722)),
    ('Max', Color(0xFFE53935)),
  ];

  @override
  Widget build(BuildContext context) {
    final zoneName = HealthUtils.currentZone(bpm, age);
    final zoneIndex =
        _zones.indexWhere((z) => z.$1 == zoneName);
    final activeIndex = zoneIndex == -1 ? 0 : zoneIndex;
    final ranges = HealthUtils.getZoneRanges(age);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Zone: ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            Text(
              zoneName,
              style: TextStyle(
                color: _zones[activeIndex].$2,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(_zones.length, (i) {
            final isActive = i == activeIndex;
            final entry = _zones[i];
            final range = ranges[entry.$1]!;
            final label = '${range[0]}-${range[1]}';

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < _zones.length - 1 ? 3 : 0),
                child: Tooltip(
                  message: '${entry.$1}: $label BPM',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? entry.$2
                          : entry.$2.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
