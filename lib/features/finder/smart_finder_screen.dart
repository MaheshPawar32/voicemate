import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/finder_preferences_repository.dart';
import '../../services/monitoring_controller.dart';
import '../../services/monitoring_settings_repository.dart';
import '../voice_commands/voice_commands_screen.dart';
import 'clap_detection_screen.dart';
import 'finder_start_flow.dart';
import 'whistle_detection_screen.dart';

class SmartFinderScreen extends StatefulWidget {
  const SmartFinderScreen({super.key});

  @override
  State<SmartFinderScreen> createState() => _SmartFinderScreenState();
}

class _SmartFinderScreenState extends State<SmartFinderScreen> {
  final _c = MonitoringController.instance;

  Future<void> _setMethod({bool? clap, bool? whistle}) async {
    final p = _c.monitoringSettings.read();
    await _c.monitoringSettings.save(MonitoringPreferences(
      clapEnabled: clap ?? p.clapEnabled,
      whistleEnabled: whistle ?? p.whistleEnabled,
      clapSensitivity: p.clapSensitivity,
      whistleSensitivity: p.whistleSensitivity,
      autoStopMinutes: p.autoStopMinutes,
      quietHoursEnabled: p.quietHoursEnabled,
      quietStart: p.quietStart,
      quietEnd: p.quietEnd,
    ));
    setState(() {});
  }

  Future<void> _pickCooldown(FinderPreferences prefs) async {
    final picked = await showChoiceSheet<int>(
      context,
      title: 'Cooldown between alerts',
      options: {
        for (final s in FinderPreferences.cooldownOptions)
          s: s == 0 ? 'No cooldown' : '$s seconds',
      },
      current: prefs.cooldownSeconds,
    );
    if (picked == null) return;
    await _c.finderPreferences.save(prefs.copyWith(cooldownSeconds: picked));
    setState(() {});
  }

  void _open(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen))
      .then((_) => setState(() {}));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final m = _c.monitoringSettings.read();
          final voice = _c.voiceSettings.read();
          final prefs = _c.finderPreferences.read();
          final locked = _c.active;
          return Scaffold(
            appBar: AppBar(title: const Text('Smart Finder')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                ToggleRow(
                  icon: Icons.radar_rounded,
                  title: 'Enable Finder',
                  subtitle: _c.active ? 'Listening now' : 'Off',
                  value: _c.active,
                  onChanged: _c.busy
                      ? null
                      : (on) => on ? FinderStartFlow.start(context) : _c.stop(),
                ),
                if (_c.notice != null)
                  NoticeBanner(
                    message: _c.notice!,
                    color: VokeyTokens.warning,
                    onDismiss: _c.clearNotice,
                  ),
                const SectionLabel('Detection methods'),
                _MethodCheck(
                  title: 'Clap detection',
                  subtitle:
                      '${FinderPreferences.clapPatterns[prefs.clapPattern]} clap · ${prefs.clapSensitivityPct}% sensitivity',
                  value: m.clapEnabled,
                  enabled: !locked,
                  onChanged: (v) => _setMethod(clap: v),
                  onOpen: () => _open(const ClapDetectionScreen()),
                ),
                _MethodCheck(
                  title: 'Whistle detection',
                  subtitle:
                      '${(prefs.whistleMinHz / 1000).toStringAsFixed(1)}–${(prefs.whistleMaxHz / 1000).toStringAsFixed(1)} kHz · ${prefs.whistleSensitivityPct}% sensitivity',
                  value: m.whistleEnabled,
                  enabled: !locked,
                  onChanged: (v) => _setMethod(whistle: v),
                  onOpen: () => _open(const WhistleDetectionScreen()),
                ),
                _MethodCheck(
                  title: 'Voice commands',
                  subtitle: 'Offline, English (US)',
                  value: voice.enabled,
                  enabled: !locked,
                  onChanged: (v) async {
                    await _c.voiceSettings.setEnabled(v);
                    setState(() {});
                  },
                  onOpen: () => _open(const VoiceCommandsScreen()),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Stop the finder to change detection methods.',
                      style: TextStyle(color: VokeyTokens.muted, fontSize: 12),
                    ),
                  ),
                const SectionLabel('Behaviour'),
                SettingRow(
                  icon: Icons.timer_outlined,
                  title: 'Cooldown',
                  subtitle: 'Minimum gap between two alerts',
                  trailing: Text(
                    prefs.cooldownSeconds == 0
                        ? 'None'
                        : '${prefs.cooldownSeconds} s',
                    style: const TextStyle(color: VokeyTokens.muted),
                  ),
                  onTap: () => _pickCooldown(prefs),
                ),
              ],
            ),
          );
        },
      );
}

class _MethodCheck extends StatelessWidget {
  const _MethodCheck({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeonCard(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          onTap: onOpen,
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: VokeyTokens.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: VokeyTokens.muted),
            ],
          ),
        ),
      );
}
