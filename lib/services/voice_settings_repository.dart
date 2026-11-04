import 'package:hive/hive.dart';

class VoiceSettings {
  const VoiceSettings({
    this.enabled = false,
    this.lockCommandEnabled = false,
  });

  final bool enabled;
  final bool lockCommandEnabled;
}

class VoiceSettingsRepository {
  VoiceSettingsRepository(this._box);
  final Box<dynamic> _box;

  static const _voiceEnabledKey = 'voice_enabled';
  static const _voiceLockEnabledKey = 'voice_lock_command_enabled';

  VoiceSettings read() => VoiceSettings(
    enabled: _box.get(_voiceEnabledKey, defaultValue: false) == true,
    lockCommandEnabled:
        _box.get(_voiceLockEnabledKey, defaultValue: false) == true,
  );

  Future<void> setEnabled(bool value) => _box.put(_voiceEnabledKey, value);

  Future<void> setLockCommandEnabled(bool value) =>
      _box.put(_voiceLockEnabledKey, value);
}
