import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/history_repository.dart';
import '../../services/monitoring_controller.dart';

/// History (reference board). Metadata only — never audio or transcripts.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';

  static const _filters = {
    'all': 'All',
    'clap': 'Clap',
    'whistle': 'Whistle',
    'voice': 'Voice',
  };

  HistoryRepository get _repo => MonitoringController.instance.history;

  bool _matches(Map<String, dynamic> e) {
    final t = e['event_type'];
    return switch (_filter) {
      'clap' =>
        t == HistoryRepository.clapDetected || t == HistoryRepository.clapTest,
      'whistle' => t == HistoryRepository.whistleDetected ||
          t == HistoryRepository.whistleTest,
      'voice' => t == HistoryRepository.voiceFindPhone ||
          t == HistoryRepository.voiceLockPhone,
      _ => true,
    };
  }

  static String _dayLabel(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _menu(String action) async {
    if (action == 'clear') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Clear history?'),
          content: const Text(
            'Deletes all detection and monitoring records on this phone. Analytics will reset. This cannot be undone.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: VokeyTokens.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _repo.clear();
        if (mounted) setState(() {});
      }
    } else if (action == 'retention') {
      final picked = await showChoiceSheet<int>(
        context,
        title: 'Keep history for',
        options: HistoryRepository.retentionOptions,
        current: _repo.retentionDays,
      );
      if (picked != null) {
        await _repo.setRetentionDays(picked);
        if (mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        // Rebuild when the controller records a new detection.
        listenable: MonitoringController.instance,
        builder: (context, _) {
          final now = DateTime.now();
          final events = _repo.readAll().where(_matches).toList();
          final children = <Widget>[];
          String? lastDay;
          for (final e in events) {
            final at =
                DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int);
            final label = _dayLabel(at, now);
            if (label != lastDay) {
              children.add(SectionLabel(label));
              lastDay = label;
            }
            children.add(_HistoryTile(event: e, at: at));
          }
          return Scaffold(
            appBar: AppBar(
              title: const Text('History'),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'History options',
                  onSelected: _menu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'retention',
                      child: Text(
                          'Keep for: ${HistoryRepository.retentionOptions[_repo.retentionDays] ?? '30 days'}'),
                    ),
                    const PopupMenuItem(
                        value: 'clear', child: Text('Clear history')),
                  ],
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                PillSegments<String>(
                  options: _filters,
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                if (children.isEmpty)
                  EmptyState(
                    icon: Icons.history_rounded,
                    title: _filter == 'all'
                        ? 'No history yet'
                        : 'Nothing here yet',
                    message:
                        'Detections and monitoring sessions are saved here as time and type only. Vokey never saves audio or what you said.',
                  )
                else
                  ...children,
              ],
            ),
          );
        },
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event, required this.at});
  final Map<String, dynamic> event;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final type = event['event_type'] as String;
    final meta = event['metadata'] as Map<String, dynamic>;
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final (IconData icon, String title, Color color) = switch (type) {
      HistoryRepository.clapDetected => (
          Icons.back_hand_rounded,
          switch (meta['clap_pattern']) {
            2 => 'Double clap detected',
            3 => 'Triple clap detected',
            _ => 'Clap detected',
          },
          VokeyTokens.warning
        ),
      HistoryRepository.whistleDetected => (
          Icons.sports_rounded,
          'Whistle detected',
          VokeyTokens.cyan
        ),
      HistoryRepository.voiceFindPhone => (
          Icons.mic_rounded,
          'Voice: “Find my phone”',
          VokeyTokens.violet
        ),
      HistoryRepository.voiceLockPhone => (
          Icons.lock_rounded,
          'Voice: “Lock my phone”',
          VokeyTokens.violet
        ),
      HistoryRepository.clapTest => (
          Icons.science_rounded,
          'Clap · Finder Test',
          VokeyTokens.muted
        ),
      HistoryRepository.whistleTest => (
          Icons.science_rounded,
          'Whistle · Finder Test',
          VokeyTokens.muted
        ),
      HistoryRepository.monitoringSession => (
          Icons.timer_outlined,
          'Monitoring session',
          VokeyTokens.success
        ),
      _ => (
          Icons.circle_outlined,
          type.replaceAll('_', ' '),
          VokeyTokens.muted
        ),
    };
    final details = <String>[time];
    if (type == HistoryRepository.monitoringSession) {
      final ms = meta['duration_ms'];
      if (ms is num) {
        details.add(formatDuration(Duration(milliseconds: ms.toInt())));
      }
      final reason = meta['stop_reason'];
      if (reason == 'battery_low') details.add('auto-stopped: low battery');
      if (reason == 'duration_limit') details.add('auto-stopped: time limit');
    } else {
      final hz = meta['whistle_frequency_hz'];
      if (hz is num && hz > 0) {
        details.add('${(hz / 1000).toStringAsFixed(1)} kHz');
      }
      final suppressed = meta['suppressed_reason'];
      if (suppressed == 'quiet_hours') details.add('muted: quiet hours');
      if (suppressed == 'pocket_mode') details.add('muted: in pocket');
      if (meta['user_feedback'] == HistoryRepository.feedbackFalseAlarm) {
        details.add('false alarm');
      }
    }
    return SettingRow(
      icon: icon,
      iconColor: color,
      title: title,
      subtitle: details.join(' · '),
    );
  }
}
