import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/services/finder_preferences_repository.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late FinderPreferencesRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vokey_finder_prefs_');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('prefs_test');
    repo = FinderPreferencesRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('fresh install gets safe defaults', () {
    final p = repo.read();
    expect(p.clapPattern, 1);
    expect(p.clapSensitivityPct, 50);
    expect(p.whistleMinHz, 1500);
    expect(p.whistleMaxHz, 3800);
    expect(p.cooldownSeconds, 5);
    expect(p.pocketModeEnabled, isFalse);
    expect(p.batteryStopPercent, 0, reason: 'auto-stop is opt-in');
  });

  test('migrates legacy low/high presets to percentages', () async {
    await box.put('monitoring_preferences', {
      'clap_sensitivity': 'high',
      'whistle_sensitivity': 'low',
    });
    final p = repo.read();
    expect(p.clapSensitivityPct, 80);
    expect(p.whistleSensitivityPct, 20);
  });

  test('round-trips with schema version and snake_case keys', () async {
    await repo.save(const FinderPreferences(
      clapPattern: 3,
      cooldownSeconds: 10,
      pocketModeEnabled: true,
      batteryStopPercent: 15,
    ));
    final raw = Map<String, dynamic>.from(box.get('finder_preferences') as Map);
    expect(raw['schema_version'], FinderPreferences.schemaVersion);
    expect(raw['clap_pattern'], 3);
    expect(raw['battery_stop_percent'], 15);
    final p = repo.read();
    expect(p.clapPattern, 3);
    expect(p.pocketModeEnabled, isTrue);
  });

  test('clamps out-of-range and wrongly typed values', () async {
    await box.put('finder_preferences', {
      'clap_pattern': 9,
      'clap_sensitivity_pct': -5,
      'whistle_min_hz': 5000,
      'whistle_max_hz': 4000,
      'cooldown_seconds': 'ten',
      'battery_stop_percent': 99,
    });
    final p = repo.read();
    expect(p.clapPattern, 3);
    expect(p.clapSensitivityPct, 0);
    expect(p.whistleMaxHz - p.whistleMinHz, greaterThanOrEqualTo(200));
    expect(p.cooldownSeconds, 5);
    expect(p.batteryStopPercent, 50);
  });

  test('platform map omits schema version and matches native keys', () {
    final map = const FinderPreferences().toPlatformMap();
    expect(map.containsKey('schema_version'), isFalse);
    expect(
      map.keys,
      containsAll(<String>[
        'clap_pattern',
        'clap_sensitivity_pct',
        'whistle_sensitivity_pct',
        'whistle_min_hz',
        'whistle_max_hz',
        'whistle_min_duration_ms',
        'cooldown_seconds',
        'pocket_mode_enabled',
        'battery_warning_percent',
        'battery_stop_percent',
      ]),
    );
  });
}
