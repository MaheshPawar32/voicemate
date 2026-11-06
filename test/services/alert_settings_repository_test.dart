import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/services/alert_settings_repository.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;
  late AlertSettingsRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('vokey_alerts_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('alert_preferences_test');
    repository = AlertSettingsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await tempDirectory.delete(recursive: true);
  });

  test('loads safe defaults', () {
    final settings = repository.read();
    expect(settings.soundEnabled, isTrue);
    expect(settings.vibrationEnabled, isTrue);
    expect(settings.soundId, 'classic_beep');
    expect(settings.volume, 80);
    expect(settings.durationSeconds, 5);
    expect(settings.repeatEnabled, isTrue);
  });

  test('persists custom preferences', () async {
    await repository.saveSoundEnabled(false);
    await repository.saveVibrationEnabled(false);
    await repository.saveSoundId('soft_chime');
    await repository.saveVolume(42);
    await repository.saveDuration(12);
    await repository.saveRepeatEnabled(false);

    final settings = repository.read();
    expect(settings.soundEnabled, isFalse);
    expect(settings.vibrationEnabled, isFalse);
    expect(settings.soundId, 'soft_chime');
    expect(settings.volume, 42);
    expect(settings.durationSeconds, 12);
    expect(settings.repeatEnabled, isFalse);
  });

  test('clamps invalid values and rejects unknown sounds', () async {
    await repository.saveVolume(150);
    await repository.saveDuration(0);
    await repository.saveSoundId('unknown');

    final settings = repository.read();
    expect(settings.volume, 100);
    expect(settings.durationSeconds, 1);
    expect(settings.soundId, 'classic_beep');
  });
}
