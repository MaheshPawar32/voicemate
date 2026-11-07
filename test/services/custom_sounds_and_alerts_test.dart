import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/services/alert_settings_repository.dart';
import 'package:vokey/services/custom_sounds_repository.dart';

CustomSound sound(String file, [String name = 'My tone']) => CustomSound(
      id: '${CustomSound.idPrefix}$file',
      name: name,
      fileName: file,
      durationMs: 3200,
      sizeBytes: 120000,
      importedAt: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Box<dynamic> box;
  late AlertSettingsRepository alerts;
  late CustomSoundsRepository custom;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vokey_sounds_');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('sounds_test');
    alerts = AlertSettingsRepository(box);
    custom = CustomSoundsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  group('alert preferences', () {
    test('rising volume and auto output are the defaults', () {
      final p = alerts.read();
      expect(p.volumeRampEnabled, isTrue);
      expect(p.rampStartPercent, 25);
      expect(p.rampSeconds, 10);
      expect(p.outputPolicy, 'auto');
      expect(p.customSoundFile, isNull);
    });

    test('ramp and output round-trip and reach the native payload', () async {
      await alerts.saveAll(alerts.read().copyWith(
            volumeRampEnabled: false,
            rampStartPercent: 40,
            rampSeconds: 20,
            outputPolicy: 'headphones',
          ));
      final map = alerts.read().toPlatformMap();
      expect(map['volume_ramp_enabled'], isFalse);
      expect(map['volume_ramp_start_percent'], 40);
      expect(map['volume_ramp_seconds'], 20);
      expect(map['output_policy'], 'headphones');
    });

    test('unknown output policy and wrongly typed values fall back', () async {
      await box.put('alert_output_policy', 'ask_each_time');
      await box.put('alert_volume_ramp_seconds', 'slow');
      final p = alerts.read();
      expect(p.outputPolicy, 'auto');
      expect(p.rampSeconds, 10);
    });
  });

  group('custom sounds', () {
    test('a custom sound can be selected and its file is sent natively',
        () async {
      await custom.add(sound('abc123.mp3'));
      await alerts.saveSoundId('custom:abc123.mp3');
      final p = alerts.read();
      expect(p.soundId, 'custom:abc123.mp3');
      expect(p.toPlatformMap()['custom_sound_file'], 'abc123.mp3');
      expect(alerts.soundName(p.soundId), 'My tone');
    });

    test('an unknown custom id is rejected', () async {
      await alerts.saveSoundId('custom:missing.mp3');
      expect(alerts.read().soundId, AlertSettingsRepository.defaultSoundId);
    });

    test('deleting the selected sound falls back to the default tone',
        () async {
      await custom.add(sound('abc123.mp3'));
      await alerts.saveSoundId('custom:abc123.mp3');
      await custom.delete('custom:abc123.mp3'); // native call absent in tests
      await alerts.ensureValidSelection();
      expect(custom.readAll(), isEmpty);
      expect(alerts.read().soundId, AlertSettingsRepository.defaultSoundId);
      expect(alerts.read().toPlatformMap().containsKey('custom_sound_file'),
          isFalse);
    });

    test('rename trims, ignores blanks and caps length', () async {
      await custom.add(sound('a1.mp3', 'Old'));
      await custom.rename('custom:a1.mp3', '   ');
      expect(custom.readAll().single.name, 'Old');
      await custom.rename('custom:a1.mp3', '  New name  ');
      expect(custom.readAll().single.name, 'New name');
      await custom.rename('custom:a1.mp3', 'x' * 80);
      expect(custom.readAll().single.name.length, 40);
    });

    test('corrupt entries are skipped', () async {
      await box.put(CustomSoundsRepository.storageKey, [
        {'file_name': 'ok.mp3', 'name': 'OK'},
        {'name': 'no file'},
        'garbage',
      ]);
      expect(custom.readAll().map((s) => s.id), ['custom:ok.mp3']);
    });

    test('import is refused at the sound limit before opening the picker',
        () async {
      for (var i = 0; i < CustomSoundsRepository.maxSounds; i++) {
        await custom.add(sound('s$i.mp3'));
      }
      expect(custom.importFromDevice(), throwsA(isA<CustomSoundException>()));
    });
  });
}
