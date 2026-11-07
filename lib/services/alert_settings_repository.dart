import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../core/storage/safe_read.dart';
import 'custom_sounds_repository.dart';

class AlertPreferences {
  const AlertPreferences({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.soundId = 'classic_beep',
    this.volume = 80,
    this.durationSeconds = 5,
    this.repeatEnabled = true,
    this.flashlightEnabled = false,
    this.flashPattern = 'single',
    this.volumeRampEnabled = true,
    this.rampStartPercent = 25,
    this.rampSeconds = 10,
    this.outputPolicy = 'auto',
    this.customSoundFile,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final String soundId;

  /// Maximum alert level (player gain). Device volume is never changed.
  final int volume;
  final int durationSeconds;
  final bool repeatEnabled;
  final bool flashlightEnabled;
  final String flashPattern;

  /// Gradually rising volume.
  final bool volumeRampEnabled;

  /// Starting level as a percentage of [volume].
  final int rampStartPercent;
  final int rampSeconds;

  /// auto | speaker | headphones
  final String outputPolicy;

  /// Private file name when [soundId] is a custom sound.
  final String? customSoundFile;

  AlertPreferences copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? soundId,
    int? volume,
    int? durationSeconds,
    bool? repeatEnabled,
    bool? flashlightEnabled,
    String? flashPattern,
    bool? volumeRampEnabled,
    int? rampStartPercent,
    int? rampSeconds,
    String? outputPolicy,
  }) =>
      AlertPreferences(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        soundId: soundId ?? this.soundId,
        volume: volume ?? this.volume,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        repeatEnabled: repeatEnabled ?? this.repeatEnabled,
        flashlightEnabled: flashlightEnabled ?? this.flashlightEnabled,
        flashPattern: flashPattern ?? this.flashPattern,
        volumeRampEnabled: volumeRampEnabled ?? this.volumeRampEnabled,
        rampStartPercent: rampStartPercent ?? this.rampStartPercent,
        rampSeconds: rampSeconds ?? this.rampSeconds,
        outputPolicy: outputPolicy ?? this.outputPolicy,
        // A changed sound id invalidates the resolved file.
        customSoundFile: soundId == null ? customSoundFile : null,
      );

  Map<String, Object> toPlatformMap() => {
        'sound_enabled': soundEnabled,
        'vibration_enabled': vibrationEnabled,
        'sound_id': soundId,
        'alert_volume': volume,
        'alert_duration_seconds': durationSeconds,
        'repeat_enabled': repeatEnabled,
        'flashlight_enabled': flashlightEnabled,
        'flash_pattern': flashPattern,
        'volume_ramp_enabled': volumeRampEnabled,
        'volume_ramp_start_percent': rampStartPercent,
        'volume_ramp_seconds': rampSeconds,
        'output_policy': outputPolicy,
        if (customSoundFile != null) 'custom_sound_file': customSoundFile!,
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
  static const _flashlightEnabled = 'alert_flashlight_enabled';
  static const _flashPattern = 'alert_flash_pattern';
  static const _rampEnabled = 'alert_volume_ramp_enabled';
  static const _rampStart = 'alert_volume_ramp_start_percent';
  static const _rampSeconds = 'alert_volume_ramp_seconds';
  static const _outputPolicy = 'alert_output_policy';

  static const defaultSoundId = 'classic_beep';

  static const supportedFlashPatterns = <String, String>{
    'single': 'Single pulses',
    'double': 'Double pulses',
    'sos': 'SOS pattern',
  };

  static const supportedSounds = <String, String>{
    'classic_beep': 'Classic beep',
    'soft_chime': 'Soft chime',
    'double_beep': 'Double beep',
    'alert_tone': 'Alert tone',
  };

  static const outputPolicies = <String, String>{
    'auto': 'Auto (recommended)',
    'speaker': 'Speaker only',
    'headphones': 'Headphones only',
  };

  CustomSoundsRepository get customSounds => CustomSoundsRepository(_box);

  bool isValidSoundId(Object? id) =>
      id is String &&
      (supportedSounds.containsKey(id) || customSounds.byId(id) != null);

  String soundName(String id) =>
      supportedSounds[id] ?? customSounds.byId(id)?.name ?? 'Classic beep';

  AlertPreferences read() {
    final rawId = _box.get(_soundId, defaultValue: defaultSoundId);
    final soundId = isValidSoundId(rawId) ? rawId as String : defaultSoundId;
    final rawPattern = _box.get(_flashPattern, defaultValue: 'single');
    final rawPolicy = _box.get(_outputPolicy, defaultValue: 'auto');
    return AlertPreferences(
      soundEnabled: _box.get(_soundEnabled, defaultValue: true) == true,
      vibrationEnabled: _box.get(_vibrationEnabled, defaultValue: true) == true,
      soundId: soundId,
      volume: readInt(_box.get(_volume), 80).clamp(0, 100),
      durationSeconds: readInt(_box.get(_duration), 5).clamp(1, 30),
      repeatEnabled: _box.get(_repeat, defaultValue: true) == true,
      flashlightEnabled:
          _box.get(_flashlightEnabled, defaultValue: false) == true,
      flashPattern: supportedFlashPatterns.containsKey(rawPattern)
          ? rawPattern as String
          : 'single',
      volumeRampEnabled: _box.get(_rampEnabled, defaultValue: true) == true,
      rampStartPercent: readInt(_box.get(_rampStart), 25).clamp(0, 100),
      rampSeconds: readInt(_box.get(_rampSeconds), 10).clamp(1, 60),
      outputPolicy:
          outputPolicies.containsKey(rawPolicy) ? rawPolicy as String : 'auto',
      customSoundFile: customSounds.byId(soundId)?.fileName,
    );
  }

  Future<void> saveAll(AlertPreferences p) async {
    await saveSoundEnabled(p.soundEnabled);
    await saveVibrationEnabled(p.vibrationEnabled);
    await saveSoundId(p.soundId);
    await saveVolume(p.volume);
    await saveDuration(p.durationSeconds);
    await saveRepeatEnabled(p.repeatEnabled);
    await saveFlashlightEnabled(p.flashlightEnabled);
    await saveFlashPattern(p.flashPattern);
    await _box.put(_rampEnabled, p.volumeRampEnabled);
    await _box.put(_rampStart, p.rampStartPercent.clamp(0, 100));
    await _box.put(_rampSeconds, p.rampSeconds.clamp(1, 60));
    await _box.put(
      _outputPolicy,
      outputPolicies.containsKey(p.outputPolicy) ? p.outputPolicy : 'auto',
    );
  }

  Future<void> saveSoundEnabled(bool value) => _box.put(_soundEnabled, value);
  Future<void> saveVibrationEnabled(bool value) =>
      _box.put(_vibrationEnabled, value);
  Future<void> saveSoundId(String value) =>
      _box.put(_soundId, isValidSoundId(value) ? value : defaultSoundId);
  Future<void> saveVolume(int value) => _box.put(_volume, value.clamp(0, 100));
  Future<void> saveDuration(int value) =>
      _box.put(_duration, value.clamp(1, 30));
  Future<void> saveRepeatEnabled(bool value) => _box.put(_repeat, value);
  Future<void> saveFlashlightEnabled(bool value) =>
      _box.put(_flashlightEnabled, value);
  Future<void> saveFlashPattern(String value) => _box.put(_flashPattern,
      supportedFlashPatterns.containsKey(value) ? value : 'single');

  /// If the selected custom sound is deleted, fall back to the default tone.
  Future<void> ensureValidSelection() async {
    if (!isValidSoundId(_box.get(_soundId))) {
      await _box.put(_soundId, defaultSoundId);
    }
  }

  Future<void> preview(AlertPreferences preferences) async {
    const channel = MethodChannel('com.dev.vokey/monitoring/methods');
    final resolved = preferences.customSoundFile == null &&
            CustomSound.isCustomId(preferences.soundId)
        ? AlertPreferences(
            soundEnabled: preferences.soundEnabled,
            vibrationEnabled: preferences.vibrationEnabled,
            soundId: preferences.soundId,
            volume: preferences.volume,
            durationSeconds: preferences.durationSeconds,
            repeatEnabled: preferences.repeatEnabled,
            flashlightEnabled: preferences.flashlightEnabled,
            flashPattern: preferences.flashPattern,
            volumeRampEnabled: preferences.volumeRampEnabled,
            rampStartPercent: preferences.rampStartPercent,
            rampSeconds: preferences.rampSeconds,
            outputPolicy: preferences.outputPolicy,
            customSoundFile: customSounds.byId(preferences.soundId)?.fileName,
          )
        : preferences;
    await channel.invokeMethod<void>('previewAlert', resolved.toPlatformMap());
  }

  Future<void> stopPreview() async {
    const channel = MethodChannel('com.dev.vokey/monitoring/methods');
    await channel.invokeMethod<void>('stopAlertPreview');
  }
}
