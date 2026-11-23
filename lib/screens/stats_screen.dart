import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../utils/session_storage.dart';
import '../utils/health_utils.dart';

/// Statistics and history screen showing past sessions and overall trends.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Session> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionStorage.getSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Statistics'),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _emptyState()
              : _sessionList(),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No sessions yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a monitoring session from the Live tab',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionList() {
    // Overall summary
    final allBpm = _sessions.expand((s) => s.bpmReadings).toList();
    final overallAvg = allBpm.isEmpty
        ? 0
        : (allBpm.reduce((a, b) => a + b) ~/ allBpm.length);
    final overallMax = allBpm.isEmpty
        ? 0
        : allBpm.reduce((a, b) => a > b ? a : b);
    final overallMin = allBpm.isEmpty
        ? 0
        : allBpm.reduce((a, b) => a < b ? a : b);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _summaryCard(overallAvg, overallMax, overallMin, _sessions.length);
        }
        final session = _sessions[index - 1];
        return _sessionCard(session);
      },
    );
  }

  Widget _summaryCard(int avg, int max, int min, int sessionCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$sessionCount sessions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryStat('Avg', '$avg', 'BPM'),
              _summaryStat('Max', '$max', 'BPM'),
              _summaryStat('Min', '$min', 'BPM'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recovery: ${HealthUtils.recoveryScore(avg)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$label $unit',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _sessionCard(Session session) {
    final duration = session.duration;
    final durationStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    final dateStr = DateFormat('MMM d, y • h:mm a').format(session.startTime);

    // Build chart data from session bpm readings (sample if too many)
    final spots = <FlSpot>[];
    final readings = session.bpmReadings;
    final step = readings.length > 100 ? readings.length ~/ 100 : 1;
    for (var i = 0; i < readings.length; i += step) {
      spots.add(FlSpot(i.toDouble(), readings[i].toDouble()));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        collapsedIconColor: Colors.white.withOpacity(0.4),
        iconColor: Colors.white.withOpacity(0.6),
        title: Text(
          dateStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _miniStat('Avg', '${session.avgBpm}'),
              const SizedBox(width: 12),
              _miniStat('Max', '${session.maxBpm}'),
              const SizedBox(width: 12),
              _miniStat('Dur', durationStr),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.spo2Readings.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniStat('Avg SpO2', '${session.avgSpo2}%'),
                      _miniStat(
                        'Min BPM',
                        '${session.minBpm}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (spots.length > 1)
                  SizedBox(
                    height: 120,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: spots.first.x,
                        maxX: spots.last.x,
                        minY: 40,
                        maxY: 180,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 2,
                            color: const Color(0xFFE53935),
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFE53935).withOpacity(0.2),
                                  const Color(0xFFE53935).withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${readings.length} readings',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text(
          'Clear History?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all saved sessions. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SessionStorage.clearSessions();
      _loadSessions();
    }
  }
}
