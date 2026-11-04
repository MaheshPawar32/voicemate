import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/alert_settings_repository.dart';
import '../sound_library/sound_library_screen.dart';

class AlertStudioScreen extends StatefulWidget {
  const AlertStudioScreen({super.key});

  @override
  State<AlertStudioScreen> createState() => _AlertStudioScreenState();
}

class _AlertStudioScreenState extends State<AlertStudioScreen> {
  late final AlertSettingsRepository _repository;
  late AlertPreferences _preferences;
  bool _previewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = AlertSettingsRepository(
      Hive.box<dynamic>('voicemate_settings'),
    );
    _preferences = _repository.read();
  }

  @override
  void dispose() {
    if (_previewing) {
      _repository.stopPreview();
    }
    super.dispose();
  }

  Future<void> _saveAndSet(AlertPreferences next) async {
    setState(() {
      _preferences = next;
      _error = null;
    });
    await _repository.saveSoundEnabled(next.soundEnabled);
    await _repository.saveVibrationEnabled(next.vibrationEnabled);
    await _repository.saveSoundId(next.soundId);
    await _repository.saveVolume(next.volume);
    await _repository.saveDuration(next.durationSeconds);
    await _repository.saveRepeatEnabled(next.repeatEnabled);
    await _repository.saveFlashlightEnabled(next.flashlightEnabled);
    await _repository.saveFlashPattern(next.flashPattern);
  }

  Future<void> _preview() async {
    if (_previewing) {
      await _repository.stopPreview();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      await _repository.preview(_preferences);
      await Future<void>.delayed(
        Duration(seconds: _preferences.durationSeconds),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _openSoundLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SoundLibraryScreen(),
      ),
    );
    if (!mounted) return;
    setState(() => _preferences = _repository.read());
  }

  @override
  Widget build(BuildContext context) {
    final soundName =
        AlertSettingsRepository.supportedSounds[_preferences.soundId] ??
            'Classic beep';
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Studio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VoiceMateApp.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: VoiceMateApp.cyan.withValues(alpha: .18),
              ),
            ),
            child: const Text(
              'Choose how your phone responds when VoiceMate detects a clap or whistle. These preferences are saved on this device.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 22),
          const Text('ALERT OUTPUTS', style: TextStyle(
            color: VoiceMateApp.cyan,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          )),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound'),
            subtitle: const Text('Play a local alert tone'),
            value: _preferences.soundEnabled,
            activeThumbColor: VoiceMateApp.cyan,
            onChanged: (value) => _saveAndSet(AlertPreferences(
              soundEnabled: value,
              vibrationEnabled: _preferences.vibrationEnabled,
              soundId: _preferences.soundId,
              volume: _preferences.volume,
              durationSeconds: _preferences.durationSeconds,
              repeatEnabled: _preferences.repeatEnabled,
              flashlightEnabled: _preferences.flashlightEnabled,
              flashPattern: _preferences.flashPattern,
            )),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibration'),
            subtitle: const Text('Use the device vibrator'),
            value: _preferences.vibrationEnabled,
            activeThumbColor: VoiceMateApp.cyan,
            onChanged: (value) => _saveAndSet(AlertPreferences(
              soundEnabled: _preferences.soundEnabled,
              vibrationEnabled: value,
              soundId: _preferences.soundId,
              volume: _preferences.volume,
              durationSeconds: _preferences.durationSeconds,
              repeatEnabled: _preferences.repeatEnabled,
              flashlightEnabled: _preferences.flashlightEnabled,
              flashPattern: _preferences.flashPattern,
            )),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Flashlight pulses'),
            subtitle: const Text(
              'Blink the rear LED on compatible devices when the finder is triggered.'),
            value: _preferences.flashlightEnabled,
            activeThumbColor: VoiceMateApp.cyan,
            onChanged: (value) => _saveAndSet(AlertPreferences(
              soundEnabled: _preferences.soundEnabled,
              vibrationEnabled: _preferences.vibrationEnabled,
              soundId: _preferences.soundId,
              volume: _preferences.volume,
              durationSeconds: _preferences.durationSeconds,
              repeatEnabled: _preferences.repeatEnabled,
              flashlightEnabled: value,
              flashPattern: _preferences.flashPattern,
            )),
          ),
          if (_preferences.flashlightEnabled) ...[
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _preferences.flashPattern,
              decoration: const InputDecoration(
                labelText: 'Flash pattern',
              ),
              items: AlertSettingsRepository.supportedFlashPatterns.entries
                  .map((entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final next = AlertPreferences(
                  soundEnabled: _preferences.soundEnabled,
                  vibrationEnabled: _preferences.vibrationEnabled,
                  soundId: _preferences.soundId,
                  volume: _preferences.volume,
                  durationSeconds: _preferences.durationSeconds,
                  repeatEnabled: _preferences.repeatEnabled,
                  flashlightEnabled: true,
                  flashPattern: value,
                );
                _saveAndSet(next);
              },
            ),
          ],
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.library_music_rounded,
              color: VoiceMateApp.cyan),
            title: const Text('Selected sound'),
            subtitle: Text(soundName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openSoundLibrary,
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('Volume',
              style: TextStyle(fontWeight: FontWeight.w700))),
            Text('${_preferences.volume}%',
              style: const TextStyle(color: VoiceMateApp.cyan)),
          ]),
          Slider(
            value: _preferences.volume.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: VoiceMateApp.cyan,
            onChanged: (value) => setState(() {
              _preferences = AlertPreferences(
                soundEnabled: _preferences.soundEnabled,
                vibrationEnabled: _preferences.vibrationEnabled,
                soundId: _preferences.soundId,
                volume: value.round(),
                durationSeconds: _preferences.durationSeconds,
                repeatEnabled: _preferences.repeatEnabled,
              );
            }),
            onChangeEnd: (value) =>
                _repository.saveVolume(value.round()),
          ),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: Text('Alert duration',
              style: TextStyle(fontWeight: FontWeight.w700))),
            Text('${_preferences.durationSeconds} sec',
              style: const TextStyle(color: VoiceMateApp.cyan)),
          ]),
          Slider(
            value: _preferences.durationSeconds.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            activeColor: VoiceMateApp.cyan,
            onChanged: (value) => setState(() {
              _preferences = AlertPreferences(
                soundEnabled: _preferences.soundEnabled,
                vibrationEnabled: _preferences.vibrationEnabled,
                soundId: _preferences.soundId,
                volume: _preferences.volume,
                durationSeconds: value.round(),
                repeatEnabled: _preferences.repeatEnabled,
              );
            }),
            onChangeEnd: (value) =>
                _repository.saveDuration(value.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeat alert'),
            subtitle: const Text('Repeat the tone and vibration during the selected duration'),
            value: _preferences.repeatEnabled,
            activeThumbColor: VoiceMateApp.cyan,
            onChanged: (value) => _saveAndSet(AlertPreferences(
              soundEnabled: _preferences.soundEnabled,
              vibrationEnabled: _preferences.vibrationEnabled,
              soundId: _preferences.soundId,
              volume: _preferences.volume,
              durationSeconds: _preferences.durationSeconds,
              repeatEnabled: value,
            )),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(
              color: Color(0xFFFFA7B2))),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _previewing ? null : _preview,
            icon: Icon(_previewing
              ? Icons.hourglass_top_rounded
              : Icons.play_arrow_rounded),
            label: Text(_previewing ? 'Playing preview…' : 'Preview alert'),
            style: FilledButton.styleFrom(
              backgroundColor: VoiceMateApp.cyan,
              foregroundColor: const Color(0xFF06111D),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The finder uses these saved settings the next time monitoring starts. Flashlight pulses require camera permission and a compatible rear LED. Android may make the torch unavailable when another app is using the camera.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VoiceMateApp.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
