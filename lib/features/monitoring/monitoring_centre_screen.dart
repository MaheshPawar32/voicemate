import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/vokey_app.dart';
import '../../services/finder_monitoring_service.dart';
import '../../services/monitoring_settings_repository.dart';

class MonitoringCentreScreen extends StatefulWidget {
  const MonitoringCentreScreen({super.key});

  @override
  State<MonitoringCentreScreen> createState() => _MonitoringCentreScreenState();
}

class _MonitoringCentreScreenState extends State<MonitoringCentreScreen> {
  final FinderMonitoringService _service = FinderMonitoringService();
  late final MonitoringSettingsRepository _repository;
  late MonitoringPreferences _preferences;
  bool _monitoringActive = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = MonitoringSettingsRepository(
      Hive.box<dynamic>('vokey_settings'),
    );
    _preferences = _repository.read();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final active = await _service.isActive();
      if (!mounted) return;
      setState(() {
        _monitoringActive = active;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save(MonitoringPreferences next) async {
    setState(() {
      _preferences = next;
      _error = null;
    });
    try {
      await _repository.save(next);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _setTime({required bool start}) async {
    final current = start ? _preferences.quietStart : _preferences.quietEnd;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (start ? 22 : 7),
      minute: int.tryParse(parts.last) ?? 0,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null || !mounted) return;
    final value = _formatTime(selected);
    final next = MonitoringPreferences(
      clapEnabled: _preferences.clapEnabled,
      whistleEnabled: _preferences.whistleEnabled,
      clapSensitivity: _preferences.clapSensitivity,
      whistleSensitivity: _preferences.whistleSensitivity,
      autoStopMinutes: _preferences.autoStopMinutes,
      quietHoursEnabled: _preferences.quietHoursEnabled,
      quietStart: start ? value : _preferences.quietStart,
      quietEnd: start ? _preferences.quietEnd : value,
    );
    await _save(next);
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  MonitoringPreferences _copy({
    bool? clapEnabled,
    bool? whistleEnabled,
    String? clapSensitivity,
    String? whistleSensitivity,
    int? autoStopMinutes,
    bool? quietHoursEnabled,
  }) =>
      MonitoringPreferences(
        clapEnabled: clapEnabled ?? _preferences.clapEnabled,
        whistleEnabled: whistleEnabled ?? _preferences.whistleEnabled,
        clapSensitivity: clapSensitivity ?? _preferences.clapSensitivity,
        whistleSensitivity:
            whistleSensitivity ?? _preferences.whistleSensitivity,
        autoStopMinutes: autoStopMinutes ?? _preferences.autoStopMinutes,
        quietHoursEnabled: quietHoursEnabled ?? _preferences.quietHoursEnabled,
        quietStart: _preferences.quietStart,
        quietEnd: _preferences.quietEnd,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Monitoring Centre'),
          actions: [
            IconButton(
              tooltip: 'Refresh monitoring status',
              onPressed: _loading ? null : _refreshStatus,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: VokeyApp.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: (_monitoringActive
                                ? const Color(0xFF38D99A)
                                : VokeyApp.cyan)
                            .withValues(alpha: .22),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _monitoringActive
                            ? Icons.hearing_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: _monitoringActive
                            ? const Color(0xFF38D99A)
                            : VokeyApp.cyan,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _monitoringActive
                                ? 'Finder is running'
                                : 'Finder is stopped',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Settings below apply the next time monitoring starts.',
                            style:
                                TextStyle(color: VokeyApp.muted, fontSize: 12),
                          ),
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  const Text('DETECTORS',
                      style: TextStyle(
                        color: VokeyApp.cyan,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      )),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Clap detection'),
                    subtitle: const Text('Detect short, sharp clap sounds'),
                    value: _preferences.clapEnabled,
                    activeThumbColor: VokeyApp.cyan,
                    onChanged: (value) => _save(_copy(clapEnabled: value)),
                  ),
                  if (_preferences.clapEnabled)
                    _SensitivityDropdown(
                      label: 'Clap sensitivity',
                      value: _preferences.clapSensitivity,
                      onChanged: (value) =>
                          _save(_copy(clapSensitivity: value)),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Whistle detection'),
                    subtitle: const Text('Detect sustained whistle-like tones'),
                    value: _preferences.whistleEnabled,
                    activeThumbColor: VokeyApp.cyan,
                    onChanged: (value) => _save(_copy(whistleEnabled: value)),
                  ),
                  if (_preferences.whistleEnabled)
                    _SensitivityDropdown(
                      label: 'Whistle sensitivity',
                      value: _preferences.whistleSensitivity,
                      onChanged: (value) =>
                          _save(_copy(whistleSensitivity: value)),
                    ),
                  const SizedBox(height: 22),
                  const Text('MONITORING DURATION',
                      style: TextStyle(
                        color: VokeyApp.cyan,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      )),
                  DropdownButtonFormField<int>(
                    initialValue: _preferences.autoStopMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Automatically stop finder after',
                    ),
                    items: MonitoringPreferences.autoStopOptions.entries
                        .map((entry) => DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _save(_copy(autoStopMinutes: value));
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  const Text('QUIET HOURS',
                      style: TextStyle(
                        color: VokeyApp.cyan,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      )),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mute finder alerts during quiet hours'),
                    subtitle: const Text(
                      'Detection continues and is saved to history, but sound, vibration and flashlight are suppressed.',
                    ),
                    value: _preferences.quietHoursEnabled,
                    activeThumbColor: VokeyApp.cyan,
                    onChanged: (value) =>
                        _save(_copy(quietHoursEnabled: value)),
                  ),
                  if (_preferences.quietHoursEnabled) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.nights_stay_outlined,
                            color: VokeyApp.cyan),
                        title: const Text('Quiet hours start'),
                        trailing: Text(_preferences.quietStart),
                        onTap: () => _setTime(start: true),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.wb_sunny_outlined,
                            color: VokeyApp.cyan),
                        title: const Text('Quiet hours end'),
                        trailing: Text(_preferences.quietEnd),
                        onTap: () => _setTime(start: false),
                      ),
                    ),
                  ],
                  if (!_preferences.clapEnabled &&
                      !_preferences.whistleEnabled) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Both sound detectors are disabled. Enable at least one detector or turn on offline voice commands before starting the finder.',
                      style: TextStyle(color: Color(0xFFFFBE55), height: 1.45),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        style: const TextStyle(color: Color(0xFFFFA7B2))),
                  ],
                ],
              ),
      );
}

class _SensitivityDropdown extends StatelessWidget {
  const _SensitivityDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: MonitoringPreferences.sensitivityOptions.entries
              .map((entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}
