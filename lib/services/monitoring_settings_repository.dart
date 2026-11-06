import 'package:hive/hive.dart';

import '../core/storage/safe_read.dart';

class MonitoringPreferences {
  const MonitoringPreferences({
    this.clapEnabled = true,
    this.whistleEnabled = true,
    this.clapSensitivity = 'normal',
    this.whistleSensitivity = 'normal',
    this.autoStopMinutes = 0,
    this.quietHoursEnabled = false,
    this.quietStart = '22:00',
    this.quietEnd = '07:00',
  });

  final bool clapEnabled;
  final bool whistleEnabled;
  final String clapSensitivity;
  final String whistleSensitivity;
  final int autoStopMinutes;
  final bool quietHoursEnabled;
  final String quietStart;
  final String quietEnd;

  static const sensitivityOptions = <String, String>{
    'low': 'Low · fewer false triggers',
    'normal': 'Normal · balanced',
    'high': 'High · more sensitive',
  };

  static const autoStopOptions = <int, String>{
    0: 'Never',
    15: '15 minutes',
    30: '30 minutes',
    60: '1 hour',
    120: '2 hours',
    180: '3 hours',
    360: '6 hours',
  };

  Map<String, Object> toMap() => {
        'clap_enabled': clapEnabled,
        'whistle_enabled': whistleEnabled,
        'clap_sensitivity': clapSensitivity,
        'whistle_sensitivity': whistleSensitivity,
        'auto_stop_minutes': autoStopMinutes,
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_start': quietStart,
        'quiet_end': quietEnd,
      };

  Map<String, Object> toPlatformMap() => toMap();
}

class MonitoringSettingsRepository {
  MonitoringSettingsRepository(this._box);

  final Box<dynamic> _box;
  static const _key = 'monitoring_preferences';

  MonitoringPreferences read() {
    final raw = _box.get(_key);
    if (raw is! Map) return const MonitoringPreferences();
    final map = Map<String, dynamic>.from(raw);

    final clapSensitivity = map['clap_sensitivity'];
    final whistleSensitivity = map['whistle_sensitivity'];
    final autoStop = readInt(map['auto_stop_minutes'], 0);
    return MonitoringPreferences(
      clapEnabled: map['clap_enabled'] != false,
      whistleEnabled: map['whistle_enabled'] != false,
      clapSensitivity:
          MonitoringPreferences.sensitivityOptions.containsKey(clapSensitivity)
              ? clapSensitivity as String
              : 'normal',
      whistleSensitivity: MonitoringPreferences.sensitivityOptions
              .containsKey(whistleSensitivity)
          ? whistleSensitivity as String
          : 'normal',
      autoStopMinutes:
          MonitoringPreferences.autoStopOptions.containsKey(autoStop)
              ? autoStop
              : 0,
      quietHoursEnabled: map['quiet_hours_enabled'] == true,
      quietStart: _normalizeTime(map['quiet_start'], '22:00'),
      quietEnd: _normalizeTime(map['quiet_end'], '07:00'),
    );
  }

  Future<void> save(MonitoringPreferences preferences) =>
      _box.put(_key, preferences.toMap());

  static String _normalizeTime(dynamic value, String fallback) {
    if (value is! String || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
      return fallback;
    }
    final pieces = value.split(':');
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return fallback;
    }
    return value;
  }
}
