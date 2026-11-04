import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/alert_settings_repository.dart';

class SoundLibraryScreen extends StatefulWidget {
  const SoundLibraryScreen({super.key});

  @override
  State<SoundLibraryScreen> createState() => _SoundLibraryScreenState();
}

class _SoundLibraryScreenState extends State<SoundLibraryScreen> {
  late final AlertSettingsRepository _repository;
  late String _selected;
  String? _previewing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = AlertSettingsRepository(
      Hive.box<dynamic>('voicemate_settings'),
    );
    _selected = _repository.read().soundId;
  }

  @override
  void dispose() {
    if (_previewing != null) _repository.stopPreview();
    super.dispose();
  }

  Future<void> _select(String soundId) async {
    await _repository.saveSoundId(soundId);
    if (mounted) setState(() => _selected = soundId);
  }

  Future<void> _preview(String soundId) async {
    setState(() {
      _previewing = soundId;
      _error = null;
    });
    final current = _repository.read();
    try {
      await _repository.preview(AlertPreferences(
        soundEnabled: true,
        vibrationEnabled: false,
        soundId: soundId,
        volume: current.volume,
        durationSeconds: 2,
        repeatEnabled: false,
      ));
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _previewing = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sound Library')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Choose one of VoiceMate’s built-in alert tones. All tones are generated locally by Android; no audio files or internet connection are required.',
          style: TextStyle(color: VoiceMateApp.muted, height: 1.5),
        ),
        const SizedBox(height: 18),
        ...AlertSettingsRepository.supportedSounds.entries.map((entry) {
          final selected = _selected == entry.key;
          final playing = _previewing == entry.key;
          return Card(
            child: ListTile(
              leading: Icon(
                selected ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
                color: selected ? VoiceMateApp.cyan : VoiceMateApp.muted,
              ),
              title: Text(entry.value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(selected ? 'Selected for finder alerts' : 'Built-in tone'),
              trailing: IconButton(
                tooltip: 'Preview ${entry.value}',
                onPressed: playing ? null : () => _preview(entry.key),
                icon: Icon(
                  playing ? Icons.volume_up_rounded
                    : Icons.play_circle_outline_rounded,
                  color: VoiceMateApp.cyan,
                ),
              ),
              onTap: () => _select(entry.key),
            ),
          );
        }),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFFFA7B2))),
        ],
      ],
    ),
  );
}
