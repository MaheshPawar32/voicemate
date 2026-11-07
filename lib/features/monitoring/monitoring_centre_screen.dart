import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/monitoring_controller.dart';
import '../../services/monitoring_settings_repository.dart';

/// Schedule & quiet hours (opened from Monitoring Centre and Settings).
/// Detection methods and sensitivity live in Smart Finder / Clap / Whistle.
class MonitoringCentreScreen extends StatefulWidget {
  const MonitoringCentreScreen({super.key});

  @override
  State<MonitoringCentreScreen> createState() => _MonitoringCentreScreenState();
}

class _MonitoringCentreScreenState extends State<MonitoringCentreScreen> {
  final _c = MonitoringController.instance;
  late MonitoringPreferences _p = _c.monitoringSettings.read();
  String? _error;

  Future<void> _save(MonitoringPreferences next) async {
    setState(() {
      _p = next;
      _error = null;
    });
    try {
      await _c.monitoringSettings.save(next);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final parts = (start ? _p.quietStart : _p.quietEnd).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? (start ? 22 : 7),
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _save(
        start ? _p.copyWith(quietStart: value) : _p.copyWith(quietEnd: value));
  }

  Future<void> _pickAutoStop() async {
    final picked = await showChoiceSheet<int>(
      context,
      title: 'Stop monitoring automatically after',
      options: MonitoringPreferences.autoStopOptions,
      current: _p.autoStopMinutes,
    );
    if (picked != null) await _save(_p.copyWith(autoStopMinutes: picked));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Schedule & quiet hours')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_c.active) ...[
              const NoticeBanner(
                color: VokeyTokens.warning,
                message:
                    'Monitoring is running. Changes apply the next time you start the finder.',
              ),
              const SizedBox(height: 8),
            ],
            const SectionLabel('Auto-stop'),
            SettingRow(
              icon: Icons.timer_outlined,
              title: 'Stop monitoring after',
              subtitle: 'Limits how long the microphone stays on',
              trailing: Text(
                MonitoringPreferences.autoStopOptions[_p.autoStopMinutes] ??
                    'Never',
                style: const TextStyle(color: VokeyTokens.muted),
              ),
              onTap: _pickAutoStop,
            ),
            const SizedBox(height: 10),
            const SectionLabel('Quiet hours'),
            ToggleRow(
              icon: Icons.bedtime_outlined,
              title: 'Mute alerts during quiet hours',
              subtitle: 'Detections are still logged in History',
              value: _p.quietHoursEnabled,
              onChanged: (v) => _save(_p.copyWith(quietHoursEnabled: v)),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _p.quietHoursEnabled
                  ? Column(
                      children: [
                        SettingRow(
                          icon: Icons.nightlight_round,
                          iconColor: VokeyTokens.violet,
                          title: 'Starts',
                          trailing: _TimeChip(_p.quietStart),
                          onTap: () => _pickTime(start: true),
                        ),
                        SettingRow(
                          icon: Icons.wb_sunny_outlined,
                          iconColor: VokeyTokens.warning,
                          title: 'Ends',
                          trailing: _TimeChip(_p.quietEnd),
                          onTap: () => _pickTime(start: false),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null)),
            ],
            const SizedBox(height: 18),
            const Text(
              'Quiet hours can cross midnight (for example 22:00–07:00). Monitoring never restarts by '
              'itself after you stop it, the phone restarts, or Android closes Vokey.',
              style: TextStyle(
                  color: VokeyTokens.muted, fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(this.time);
  final String time;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: VokeyTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VokeyTokens.cardBorder),
        ),
        child: Text(time,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );
}
