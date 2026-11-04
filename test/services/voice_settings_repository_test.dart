import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voicemate/services/voice_settings_repository.dart';

void main() {
  late Box<dynamic> box;
  late VoiceSettingsRepository repository;

  setUp(() async {
    Hive.init(null);
    box = await Hive.openBox<dynamic>('voice_preferences_test');
    repository = VoiceSettingsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
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
