import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Real-time scrolling line chart for heart rate BPM values.
class HeartRateChart extends StatelessWidget {
  final List<FlSpot> dataPoints;
  final Color lineColor;
  final double minY;
  final double maxY;

  const HeartRateChart({
    super.key,
    required this.dataPoints,
    this.lineColor = const Color(0xFFE53935),
    this.minY = 40,
    this.maxY = 180,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: dataPoints.length > 1 ? dataPoints.last.x : 1,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            barWidth: 2.5,
            color: lineColor,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withOpacity(0.3),
                  lineColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
