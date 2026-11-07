import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/device_info_service.dart';
import '../../services/finder_preferences_repository.dart';
import '../../services/monitoring_controller.dart';
import '../battery_centre/battery_centre_screen.dart';

/// Battery Centre (reference board): level, charging state, low-battery
/// warning and optional automatic stop. No invented battery-usage estimates.
class BatteryAwareScreen extends StatefulWidget {
  const BatteryAwareScreen({super.key});

  @override
  State<BatteryAwareScreen> createState() => _BatteryAwareScreenState();
}

class _BatteryAwareScreenState extends State<BatteryAwareScreen> {
  final _c = MonitoringController.instance;
  late FinderPreferences _prefs = _c.finderPreferences.read();
  BatterySnapshot? _battery;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await DeviceInfoService().getBatterySnapshot();
      if (mounted) setState(() => _battery = b);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save(FinderPreferences next) async {
    setState(() => _prefs = next.normalized());
    await _c.finderPreferences.save(_prefs);
  }

  @override
  Widget build(BuildContext context) {
    final b = _battery;
    final charging =
        b != null && (b.status == 'charging' || b.status == 'full');
    final level = b?.levelPercent ?? -1;
    final color = level < 0
        ? VokeyTokens.muted
        : (level <= 20 ? VokeyTokens.error : VokeyTokens.success);
    return Scaffold(
      appBar: AppBar(title: const Text('Battery Centre')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: level < 0 ? null : level / 100,
                        strokeWidth: 10,
                        color: color,
                        backgroundColor: VokeyTokens.cardBorder,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          charging
                              ? Icons.battery_charging_full_rounded
                              : Icons.battery_std_rounded,
                          color: color,
                        ),
                        Text(
                          level < 0 ? '—' : '$level%',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          b == null
                              ? (_error == null ? 'Reading…' : 'Unavailable')
                              : (charging ? 'Charging' : 'On battery'),
                          style: const TextStyle(color: VokeyTokens.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null)),
            ],
            const SectionLabel('Battery-aware monitoring'),
            ToggleRow(
              icon: Icons.battery_alert_rounded,
              title: 'Low battery warning',
              subtitle: _prefs.batteryWarningPercent > 0
                  ? 'At ${_prefs.batteryWarningPercent}%'
                  : 'Off',
              value: _prefs.batteryWarningPercent > 0,
              onChanged: (v) =>
                  _save(_prefs.copyWith(batteryWarningPercent: v ? 20 : 0)),
            ),
            if (_prefs.batteryWarningPercent > 0)
              _ThresholdSlider(
                value: _prefs.batteryWarningPercent,
                onChanged: (v) =>
                    _save(_prefs.copyWith(batteryWarningPercent: v)),
              ),
            ToggleRow(
              icon: Icons.power_settings_new_rounded,
              title: 'Auto-stop monitoring',
              subtitle: _prefs.batteryStopPercent > 0
                  ? 'Stops at ${_prefs.batteryStopPercent}% when not charging'
                  : 'Off',
              value: _prefs.batteryStopPercent > 0,
              onChanged: (v) =>
                  _save(_prefs.copyWith(batteryStopPercent: v ? 10 : 0)),
            ),
            if (_prefs.batteryStopPercent > 0)
              _ThresholdSlider(
                value: _prefs.batteryStopPercent,
                onChanged: (v) => _save(_prefs.copyWith(batteryStopPercent: v)),
              ),
            if (_c.active)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Changes apply the next time you start the finder.',
                  style: TextStyle(color: VokeyTokens.muted, fontSize: 12),
                ),
              ),
            SettingRow(
              icon: Icons.tune_rounded,
              title: 'Optimise for battery',
              subtitle: 'Battery saver, optimisation and device details',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const BatteryCentreScreen(),
              )),
            ),
            const SizedBox(height: 6),
            const Text(
              'Listening uses the microphone continuously, which uses battery. Actual usage '
              'depends on your phone; Vokey does not estimate it.',
              style: TextStyle(
                  color: VokeyTokens.muted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: Slider(
          value: value.toDouble().clamp(5, 50),
          min: 5,
          max: 50,
          divisions: 9,
          label: '$value%',
          onChanged: (v) => onChanged(v.round()),
        ),
      );
}
