import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Box<dynamic> _box;
  bool _sound = true;
  bool _vibration = true;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<dynamic>('voicemate_settings');
    _sound = _box.get('sound_enabled', defaultValue: true) == true;
    _vibration = _box.get('vibration_enabled', defaultValue: true) == true;
    _flash = _box.get('flashlight_enabled', defaultValue: false) == true;
  }

  Future<void> _save(String key, bool value) async {
    await _box.put(key, value);
    if (!mounted) return;
    setState(() {
      switch (key) {
        case 'sound_enabled':
          _sound = value;
          break;
        case 'vibration_enabled':
          _vibration = value;
          break;
        case 'flashlight_enabled':
          _flash = value;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 30), children: [
        const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Make VoiceMate work your way.', style: TextStyle(color: VoiceMateApp.muted)),
        const SizedBox(height: 25),
        _section('ALERT PREFERENCES'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Sound alerts'), subtitle: const Text('Play a sound when your phone is found'), value: _sound, activeThumbColor: VoiceMateApp.cyan, onChanged: (v) => _save('sound_enabled', v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Vibration'), subtitle: const Text('Vibrate during finder alerts'), value: _vibration, activeThumbColor: VoiceMateApp.cyan, onChanged: (v) => _save('vibration_enabled', v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Flashlight'), subtitle: const Text('Use camera flash where supported'), value: _flash, activeThumbColor: VoiceMateApp.cyan, onChanged: (v) => _save('flashlight_enabled', v)),
        const SizedBox(height: 18),
        _section('PRIVACY & DATA'),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lock_outline, color: VoiceMateApp.cyan), title: const Text('Privacy and permissions'), subtitle: const Text('Review how VoiceMate uses device permissions'), onTap: () => _info(context, 'Privacy', 'VoiceMate is designed to process detection audio on your device. Microphone permission will be requested only when you enable a listening feature.')),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.history_rounded, color: VoiceMateApp.cyan),
          title: Text('History coming soon'),
          subtitle: Text('Detection history will be added with the finder engine.'),
        ),
        const SizedBox(height: 18),
        _section('ABOUT'),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline, color: VoiceMateApp.cyan), title: Text('VoiceMate'), subtitle: Text('Version 0.1.0 · Android')),
        const SizedBox(height: 18),
        const Text('Preferences are saved locally. Background monitoring, whistle detection and alert playback are not implemented in this prototype; the alert switches currently save your choices.', style: TextStyle(color: VoiceMateApp.muted, fontSize: 12, height: 1.5)),
      ]),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(color: VoiceMateApp.cyan, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
  );

  void _info(BuildContext context, String title, String message) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }
}
