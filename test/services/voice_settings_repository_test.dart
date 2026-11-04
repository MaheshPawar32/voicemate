import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicemate/services/voice_settings_repository.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;
  late VoiceSettingsRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('voicemate_voice_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('voice_preferences_test');
    repository = VoiceSettingsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await tempDirectory.delete(recursive: true);
  });

  test('voice commands are disabled by default', () {
    expect(repository.read().enabled, isFalse);
    expect(repository.read().lockCommandEnabled, isFalse);
  });

  test('persists voice and lock command toggles', () async {
    await repository.setEnabled(true);
    await repository.setLockCommandEnabled(true);
    expect(repository.read().enabled, isTrue);
    expect(repository.read().lockCommandEnabled, isTrue);
  });
}
