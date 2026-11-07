import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/device_info_service.dart';
import '../../services/monitoring_controller.dart';
import '../finder/battery_aware_screen.dart';
import '../finder/finder_start_flow.dart';
import '../finder/pocket_mode_screen.dart';
import '../finder/smart_finder_screen.dart';
import '../help/help_and_support_screen.dart';
import 'monitoring_centre_screen.dart';

/// Monitoring Centre tab (reference board).
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _c = MonitoringController.instance;
  BatterySnapshot? _battery;
  String _route = 'unknown';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadDeviceState();
    _c.addListener(_syncTicker);
    _syncTicker();
  }

  /// One-second ticker only while monitoring, for the duration readout.
  void _syncTicker() {
    if (_c.active && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!_c.active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _loadDeviceState() async {
    try {
      final b = await DeviceInfoService().getBatterySnapshot();
      if (mounted) setState(() => _battery = b);
    } catch (_) {/* shown as unavailable */}
    final caps = await _c.service.capabilities();
    if (mounted) {
      setState(() => _route = caps['audio_route'] as String? ?? 'unknown');
    }
  }

  @override
  void dispose() {
    _c.removeListener(_syncTicker);
    _ticker?.cancel();
    super.dispose();
  }

  void _open(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen))
      .then((_) => _loadDeviceState());

  static String _routeLabel(String r) => switch (r) {
        'bluetooth' => 'Bluetooth audio',
        'wired' => 'Wired headphones',
        'usb' => 'USB audio',
        'speaker' => 'Speaker',
        _ => 'Unknown',
      };

  Future<void> _confirmStopAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Stop everything?'),
        content: const Text(
          'Stops listening, any ringing alert, the flashlight, vibration and Finder Test.',
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
            child: const Text('Stop all'),
          ),
        ],
      ),
    );
    if (ok == true) await _c.emergencyStop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final active = _c.active;
          final methods = active
              ? [
                  if (_c.clapActive) 'Clap',
                  if (_c.whistleActive) 'Whistle',
                  if (_c.voiceActive) 'Voice',
                ]
              : [
                  if (_c.monitoringSettings.read().clapEnabled) 'Clap',
                  if (_c.monitoringSettings.read().whistleEnabled) 'Whistle',
                  if (_c.voiceSettings.read().enabled) 'Voice',
                ];
          final prefs = _c.finderPreferences.read();
          final b = _battery;
          return Scaffold(
            appBar: AppBar(title: const Text('Monitoring Centre')),
            body: RefreshIndicator(
              onRefresh: () async {
                await _c.refresh();
                await _loadDeviceState();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  NeonCard(
                    glow: active ? VokeyTokens.success : null,
                    child: Row(
                      children: [
                        IconBadge(
                          icon: active
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color:
                              active ? VokeyTokens.success : VokeyTokens.muted,
                          size: 48,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active ? 'Monitoring Active' : 'Monitoring Off',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: active
                                      ? VokeyTokens.success
                                      : VokeyTokens.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                active
                                    ? 'Duration ${formatDuration(_c.elapsed)}'
                                    : 'Start the finder to listen',
                                style:
                                    const TextStyle(color: VokeyTokens.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_c.notice != null) ...[
                    const SizedBox(height: 16),
                    NoticeBanner(
                        message: _c.notice!,
                        color: VokeyTokens.warning,
                        onDismiss: _c.clearNotice),
                  ],
                  const SectionLabel('Status'),
                  SettingRow(
                    icon: Icons.hearing_rounded,
                    title: 'Detection methods',
                    subtitle:
                        methods.isEmpty ? 'None selected' : methods.join(', '),
                    onTap: () => _open(const SmartFinderScreen()),
                  ),
                  SettingRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Foreground service',
                    subtitle:
                        active ? 'Running · notification visible' : 'Stopped',
                    trailing: StatusPill(
                      active ? 'Running' : 'Stopped',
                      color: active ? VokeyTokens.success : VokeyTokens.muted,
                    ),
                  ),
                  SettingRow(
                    icon: Icons.battery_std_rounded,
                    title: 'Battery',
                    subtitle: b == null
                        ? 'Unavailable'
                        : '${b.levelPercent}% (${b.status == 'charging' || b.status == 'full' ? 'Charging' : 'On battery'})'
                            '${prefs.batteryStopPercent > 0 ? ' · auto-stop at ${prefs.batteryStopPercent}%' : ''}',
                    onTap: () => _open(const BatteryAwareScreen()),
                  ),
                  SettingRow(
                    icon: Icons.headphones_rounded,
                    title: 'Output',
                    subtitle: '${_routeLabel(_route)} (reported by Android)',
                  ),
                  SettingRow(
                    icon: Icons.inventory_2_outlined,
                    title: 'Pocket mode',
                    subtitle: !prefs.pocketModeEnabled
                        ? 'Off'
                        : (active
                            ? (_c.pocketCovered
                                ? 'In pocket · alerts muted'
                                : 'Uncovered')
                            : 'On'),
                    onTap: () => _open(const PocketModeScreen()),
                  ),
                  SettingRow(
                    icon: Icons.schedule_rounded,
                    title: 'Schedule & quiet hours',
                    subtitle: 'Auto-stop timer and muted hours',
                    onTap: () => _open(const MonitoringCentreScreen()),
                  ),
                  SettingRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Troubleshooting',
                    subtitle: 'If monitoring stops in the background',
                    onTap: () => _open(const HelpAndSupportScreen()),
                  ),
                  const SizedBox(height: 22),
                  if (active)
                    DangerButton(label: 'Stop Monitoring', onPressed: _c.stop)
                  else
                    GradientButton(
                      label: _c.busy ? 'Starting…' : 'Start Monitoring',
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          _c.busy ? null : () => FinderStartFlow.start(context),
                    ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _confirmStopAll,
                    style: TextButton.styleFrom(
                        foregroundColor: VokeyTokens.error),
                    icon: const Icon(Icons.power_settings_new_rounded),
                    label: const Text(
                        'Stop everything (alerts, flashlight, tests)'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
