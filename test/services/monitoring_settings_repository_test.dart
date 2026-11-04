import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicemate/services/monitoring_settings_repository.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late MonitoringSettingsRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voicemate_monitoring_');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('monitoring_settings_test');
    repository = MonitoringSettingsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await directory.delete(recursive: true);
  });

  test('loads safe finder defaults', () {
    final settings = repository.read();
    expect(settings.clapEnabled, isTrue);
    expect(settings.whistleEnabled, isTrue);
    expect(settings.clapSensitivity, 'normal');
    expect(settings.whistleSensitivity, 'normal');
    expect(settings.autoStopMinutes, 0);
    expect(settings.quietHoursEnabled, isFalse);
    expect(settings.quietStart, '22:00');
    expect(settings.quietEnd, '07:00');
  });

  test('persists independent detector, sensitivity and schedule options', () async {
    const settings = MonitoringPreferences(
      clapEnabled: false,
      whistleEnabled: true,
      clapSensitivity: 'high',
      whistleSensitivity: 'low',
      autoStopMinutes: 60,
      quietHoursEnabled: true,
      quietStart: '23:15',
      quietEnd: '06:45',
    );
    await repository.save(settings);

    final saved = repository.read();
    expect(saved.clapEnabled, isFalse);
    expect(saved.whistleEnabled, isTrue);
    expect(saved.clapSensitivity, 'high');
    expect(saved.whistleSensitivity, 'low');
    expect(saved.autoStopMinutes, 60);
    expect(saved.quietHoursEnabled, isTrue);
    expect(saved.quietStart, '23:15');
    expect(saved.quietEnd, '06:45');
  });

  test('rejects invalid sensitivity, duration and quiet-hour values', () async {
    await box.put('monitoring_preferences', {
      'clap_enabled': false,
      'whistle_enabled': false,
      'clap_sensitivity': 'extreme',
      'whistle_sensitivity': 'unknown',
      'auto_stop_minutes': 900,
      'quiet_hours_enabled': true,
      'quiet_start': '29:00',
      'quiet_end': 'bad',
    });

    final saved = repository.read();
    expect(saved.clapEnabled, isFalse);
    expect(saved.whistleEnabled, isFalse);
    expect(saved.clapSensitivity, 'normal');
    expect(saved.whistleSensitivity, 'normal');
    expect(saved.autoStopMinutes, 0);
    expect(saved.quietStart, '22:00');
    expect(saved.quietEnd, '07:00');
  });
}
