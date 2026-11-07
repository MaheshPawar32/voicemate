import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/detection_analytics.dart';
import '../../services/monitoring_controller.dart';

/// Detection Analytics (reference board). Local-only, computed from History.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// 0 = overview (all retained), 1 = today, 7 = last 7 days.
  int _window = 0;

  static const _windows = {0: 'Overview', 1: 'Daily', 7: 'Weekly'};

  @override
  Widget build(BuildContext context) {
    final history = MonitoringController.instance.history;
    final s = DetectionAnalytics.summarize(history.readAll(), days: _window);
    final h = s.monitoringTime.inHours;
    final m = s.monitoringTime.inMinutes.remainder(60);
    return Scaffold(
      appBar: AppBar(title: const Text('Detection Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          PillSegments<int>(
            options: _windows,
            value: _window,
            onChanged: (v) => setState(() => _window = v),
          ),
          const SizedBox(height: 16),
          NeonCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total detections',
                          style: TextStyle(color: VokeyTokens.muted)),
                      const SizedBox(height: 6),
                      Text(
                        '${s.total}',
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                _Bars(days: s.perDay),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (s.total == 0 && s.sessions == 0)
            const EmptyState(
              icon: Icons.insights_rounded,
              title: 'No data yet',
              message:
                  'Start the finder and clap or whistle. Detections and listening time appear here. Everything stays on this phone.',
            )
          else ...[
            _StatRow(
                icon: Icons.back_hand_rounded,
                label: 'Claps',
                value: '${s.claps}'),
            _StatRow(
                icon: Icons.sports_rounded,
                label: 'Whistles',
                value: '${s.whistles}'),
            _StatRow(
                icon: Icons.mic_rounded,
                label: 'Voice commands',
                value: '${s.voice}'),
            _StatRow(
              icon: Icons.thumb_down_alt_outlined,
              label: 'Marked as false alarm',
              value: '${s.falseAlarms}',
              color: VokeyTokens.warning,
            ),
            _StatRow(
              icon: Icons.timer_outlined,
              label: 'Monitoring time (${s.sessions} sessions)',
              value: h > 0 ? '${h}h ${m}m' : '${m}m',
              color: VokeyTokens.success,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Calculated on this phone from History. Clearing History or its retention period also resets these numbers.',
            style: TextStyle(
                color: VokeyTokens.muted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color = VokeyTokens.cyan,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => SettingRow(
        icon: icon,
        iconColor: color,
        title: label,
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      );
}

/// Tiny per-day bar chart (last N days). Labels give exact counts.
class _Bars extends StatelessWidget {
  const _Bars({required this.days});
  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final shown = days.length > 7 ? days.sublist(days.length - 7) : days;
    return Semantics(
      label: 'Detections per day: ${shown.map((d) => d.count).join(', ')}',
      child: SizedBox(
        height: 80,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final d in shown)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 10,
                      height: 4 + (max == 0 ? 0 : 52 * d.count / max),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [VokeyTokens.violet, VokeyTokens.cyan],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(weekday[d.day.weekday - 1],
                        style: const TextStyle(
                            color: VokeyTokens.muted, fontSize: 10)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
