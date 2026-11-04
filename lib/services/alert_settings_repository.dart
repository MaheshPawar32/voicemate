import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class AlertPreferences {
  const AlertPreferences({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.soundId = 'classic_beep',
    this.volume = 80,
    this.durationSeconds = 5,
    this.repeatEnabled = true,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final String soundId;
  final int volume;
  final int durationSeconds;
  final bool repeatEnabled;

  Map<String, Object> toPlatformMap() => {
    'sound_enabled': soundEnabled,
    'vibration_enabled': vibrationEnabled,
    'sound_id': soundId,
    'alert_volume': volume,
    'alert_duration_seconds': durationSeconds,
    'repeat_enabled': repeatEnabled,
  };
}

class AlertSettingsRepository {
  AlertSettingsRepository(this._box);

  final Box<dynamic> _box;
  static const _soundEnabled = 'alert_sound_enabled';
  static const _vibrationEnabled = 'alert_vibration_enabled';
  static const _soundId = 'alert_sound_id';
  static const _volume = 'alert_volume';
  static const _duration = 'alert_duration_seconds';
  static const _repeat = 'alert_repeat_enabled';

  static const supportedSounds = <String, String>{
    'classic_beep': 'Classic beep',
    'soft_chime': 'Soft chime',
    'double_beep': 'Double beep',
    'alert_tone': 'Alert tone',
  };

  AlertPreferences read() => AlertPreferences(
    soundEnabled: _box.get(_soundEnabled, defaultValue: true) == true,
    vibrationEnabled: _box.get(_vibrationEnabled, defaultValue: true) == true,
    soundId: supportedSounds.containsKey(
      _box.get(_soundId, defaultValue: 'classic_beep'))
        ? _box.get(_soundId, defaultValue: 'classic_beep') as String
        : 'classic_beep',
    volume: ((_box.get(_volume, defaultValue: 80) as num?)?.toInt() ?? 80)
      .clamp(0, 100).toInt(),
    durationSeconds:
      ((_box.get(_duration, defaultValue: 5) as num?)?.toInt() ?? 5)
        .clamp(1, 30).toInt(),
    repeatEnabled: _box.get(_repeat, defaultValue: true) == true,
  );

  Future<void> saveSoundEnabled(bool value) =>
      _box.put(_soundEnabled, value);
  Future<void> saveVibrationEnabled(bool value) =>
      _box.put(_vibrationEnabled, value);
  Future<void> saveSoundId(String value) =>
      _box.put(_soundId, supportedSounds.containsKey(value)
        ? value : 'classic_beep');
  Future<void> saveVolume(int value) =>
      _box.put(_volume, value.clamp(0, 100));
  Future<void> saveDuration(int value) =>
      _box.put(_duration, value.clamp(1, 30));
  Future<void> saveRepeatEnabled(bool value) =>
      _box.put(_repeat, value);

  Future<void> preview(AlertPreferences preferences) async {
    const channel = MethodChannel('com.dev.voicemate/monitoring/methods');
    await channel.invokeMethod<void>(
      'previewAlert',
      preferences.toPlatformMap(),
    );
  }

  Future<void> stopPreview() async {
    const channel = MethodChannel('com.dev.voicemate/monitoring/methods');
    await channel.invokeMethod<void>('stopAlertPreview');
  }
}
