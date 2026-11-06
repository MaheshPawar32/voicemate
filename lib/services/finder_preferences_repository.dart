import 'package:hive/hive.dart';

import '../core/storage/safe_read.dart';

/// Detection tuning + finder behaviour. Persisted as one snake_case map with
/// a schema version so future fields can be migrated safely.
class FinderPreferences {
  const FinderPreferences({
    this.clapPattern = 1,
    this.clapSensitivityPct = 50,
    this.whistleSensitivityPct = 50,
    this.whistleMinHz = 1500,
    this.whistleMaxHz = 3800,
    this.whistleMinDurationMs = 120,
    this.cooldownSeconds = 5,
    this.pocketModeEnabled = false,
    this.batteryWarningPercent = 20,
    this.batteryStopPercent = 0,
  });

  static const schemaVersion = 1;

  final int clapPattern;
  final int clapSensitivityPct;
  final int whistleSensitivityPct;
  final int whistleMinHz;
  final int whistleMaxHz;
  final int whistleMinDurationMs;
  final int cooldownSeconds;
  final bool pocketModeEnabled;

  /// 0 disables the warning.
  final int batteryWarningPercent;

  /// 0 disables automatic stop.
  final int batteryStopPercent;

  static const clapPatterns = {1: 'Single', 2: 'Double', 3: 'Triple'};
  static const cooldownOptions = [0, 3, 5, 10, 15, 30, 60];

  FinderPreferences copyWith({
    int? clapPattern,
    int? clapSensitivityPct,
    int? whistleSensitivityPct,
    int? whistleMinHz,
    int? whistleMaxHz,
    int? whistleMinDurationMs,
    int? cooldownSeconds,
    bool? pocketModeEnabled,
    int? batteryWarningPercent,
    int? batteryStopPercent,
  }) =>
      FinderPreferences(
        clapPattern: clapPattern ?? this.clapPattern,
        clapSensitivityPct: clapSensitivityPct ?? this.clapSensitivityPct,
        whistleSensitivityPct:
            whistleSensitivityPct ?? this.whistleSensitivityPct,
        whistleMinHz: whistleMinHz ?? this.whistleMinHz,
        whistleMaxHz: whistleMaxHz ?? this.whistleMaxHz,
        whistleMinDurationMs: whistleMinDurationMs ?? this.whistleMinDurationMs,
        cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
        pocketModeEnabled: pocketModeEnabled ?? this.pocketModeEnabled,
        batteryWarningPercent:
            batteryWarningPercent ?? this.batteryWarningPercent,
        batteryStopPercent: batteryStopPercent ?? this.batteryStopPercent,
      );

  /// Clamps every field into the range the native layer supports.
  FinderPreferences normalized() {
    final minHz = whistleMinHz.clamp(800, 6000);
    final maxHz = whistleMaxHz.clamp(minHz + 200, 7000);
    return FinderPreferences(
      clapPattern: clapPattern.clamp(1, 3),
      clapSensitivityPct: clapSensitivityPct.clamp(0, 100),
      whistleSensitivityPct: whistleSensitivityPct.clamp(0, 100),
      whistleMinHz: minHz,
      whistleMaxHz: maxHz,
      whistleMinDurationMs: whistleMinDurationMs.clamp(60, 2000),
      cooldownSeconds: cooldownSeconds.clamp(0, 120),
      pocketModeEnabled: pocketModeEnabled,
      batteryWarningPercent: batteryWarningPercent.clamp(0, 50),
      batteryStopPercent: batteryStopPercent.clamp(0, 50),
    );
  }

  Map<String, Object> toMap() => {
        'schema_version': schemaVersion,
        'clap_pattern': clapPattern,
        'clap_sensitivity_pct': clapSensitivityPct,
        'whistle_sensitivity_pct': whistleSensitivityPct,
        'whistle_min_hz': whistleMinHz,
        'whistle_max_hz': whistleMaxHz,
        'whistle_min_duration_ms': whistleMinDurationMs,
        'cooldown_seconds': cooldownSeconds,
        'pocket_mode_enabled': pocketModeEnabled,
        'battery_warning_percent': batteryWarningPercent,
        'battery_stop_percent': batteryStopPercent,
      };

  /// Keys understood by MonitoringConfig.fromExtras / startClapTest.
  Map<String, Object> toPlatformMap() =>
      Map.of(toMap())..remove('schema_version');
}

class FinderPreferencesRepository {
  FinderPreferencesRepository(this._box);

  final Box<dynamic> _box;
  static const storageKey = 'finder_preferences';

  /// Legacy MonitoringPreferences stored sensitivity as low/normal/high.
  static int presetToPercent(Object? preset) => switch (preset) {
        'low' => 20,
        'high' => 80,
        _ => 50,
      };

  FinderPreferences read() {
    final raw = _box.get(storageKey);
    if (raw is! Map) return _migrateFromLegacy();
    final m = Map<String, dynamic>.from(raw);
    const d = FinderPreferences();
    return FinderPreferences(
      clapPattern: readInt(m['clap_pattern'], d.clapPattern),
      clapSensitivityPct:
          readInt(m['clap_sensitivity_pct'], d.clapSensitivityPct),
      whistleSensitivityPct:
          readInt(m['whistle_sensitivity_pct'], d.whistleSensitivityPct),
      whistleMinHz: readInt(m['whistle_min_hz'], d.whistleMinHz),
      whistleMaxHz: readInt(m['whistle_max_hz'], d.whistleMaxHz),
      whistleMinDurationMs:
          readInt(m['whistle_min_duration_ms'], d.whistleMinDurationMs),
      cooldownSeconds: readInt(m['cooldown_seconds'], d.cooldownSeconds),
      pocketModeEnabled: m['pocket_mode_enabled'] == true,
      batteryWarningPercent:
          readInt(m['battery_warning_percent'], d.batteryWarningPercent),
      batteryStopPercent:
          readInt(m['battery_stop_percent'], d.batteryStopPercent),
    ).normalized();
  }

  FinderPreferences _migrateFromLegacy() {
    final legacy = _box.get('monitoring_preferences');
    if (legacy is! Map) return const FinderPreferences();
    return FinderPreferences(
      clapSensitivityPct: presetToPercent(legacy['clap_sensitivity']),
      whistleSensitivityPct: presetToPercent(legacy['whistle_sensitivity']),
    );
  }

  Future<void> save(FinderPreferences preferences) =>
      _box.put(storageKey, preferences.normalized().toMap());
}
