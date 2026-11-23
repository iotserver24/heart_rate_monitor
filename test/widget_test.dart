import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heart_rate_monitor/main.dart';

void main() {
  testWidgets('app starts on the Live screen with navigation', (tester) async {
    await tester.pumpWidget(const HeartRateApp());
    await tester.pump();

    expect(find.text('Live Monitor'), findsOneWidget);
    expect(find.byIcon(Icons.monitor_heart), findsOneWidget);
    expect(find.byIcon(Icons.insights), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
  });

  testWidgets('Live screen shows the disconnected state without a device',
      (tester) async {
    await tester.pumpWidget(const HeartRateApp());
    await tester.pump();

    // No ESP32 is connected in a test environment, so the live screen must
    // not present a measurement.
    expect(find.text('Disconnected'), findsWidgets);
  });
}
