import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/vokey_app.dart';
import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/alert_settings_repository.dart';
import '../../services/custom_sounds_repository.dart';
import '../../services/finder_monitoring_service.dart';
import '../../services/monitoring_controller.dart';

class _Entry {
  const _Entry(this.id, this.name, this.subtitle, {this.custom});
  final String id;
  final String name;
  final String subtitle;
  final CustomSound? custom;
}

/// Sound Library (reference board): built-in tones + imported sounds.
class SoundLibraryScreen extends StatefulWidget {
  const SoundLibraryScreen({super.key});

  @override
  State<SoundLibraryScreen> createState() => _SoundLibraryScreenState();
}

class _SoundLibraryScreenState extends State<SoundLibraryScreen> {
  late final AlertSettingsRepository _alerts = AlertSettingsRepository(
    Hive.box<dynamic>(AppStartupState.settingsBoxName),
  );
  CustomSoundsRepository get _custom => _alerts.customSounds;
  late String _selected = _alerts.read().soundId;
  String _category = 'all';
  String _query = '';
  String? _previewing;
  Timer? _previewTimer;
  bool _importing = false;
  String? _message;
  bool _messageIsError = false;

  StreamSubscription<FinderMonitoringEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = FinderMonitoringService().events.listen((e) {
      if (e.type == 'alert_sound_unavailable' && mounted) {
        _show(soundUnavailableMessage(e.reason), error: true);
      }
    }, onError: (_) {});
  }

  static const _categories = {
    'all': 'All',
    'builtin': 'Built-in',
    'mine': 'My sounds'
  };

  @override
  void dispose() {
    _events?.cancel();
    _previewTimer?.cancel();
    if (_previewing != null) _alerts.stopPreview();
    super.dispose();
  }

  List<_Entry> _entries() {
    final builtIn = AlertSettingsRepository.supportedSounds.entries
        .map((e) => _Entry(e.key, e.value, 'Built-in tone'));
    final mine = _custom.readAll().map((s) => _Entry(
          s.id,
          s.name,
          'My sound · ${(s.durationMs / 1000).toStringAsFixed(1)} s',
          custom: s,
        ));
    final all = [
      if (_category != 'mine') ...builtIn,
      if (_category != 'builtin') ...mine,
    ];
    final q = _query.trim().toLowerCase();
    return q.isEmpty
        ? all
        : all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  void _show(String text, {bool error = false}) => setState(() {
        _message = text;
        _messageIsError = error;
      });

  Future<void> _select(String id) async {
    await _alerts.saveSoundId(id);
    setState(() => _selected = _alerts.read().soundId);
  }

  Future<void> _preview(String id) async {
    if (_previewing == id) {
      _previewTimer?.cancel();
      await _alerts.stopPreview();
      setState(() => _previewing = null);
      return;
    }
    setState(() => _previewing = id);
    final current = _alerts.read();
    try {
      await _alerts.preview(AlertPreferences(
        soundEnabled: true,
        vibrationEnabled: false,
        soundId: id,
        volume: current.volume,
        durationSeconds: 3,
        repeatEnabled: false,
        volumeRampEnabled: false,
        outputPolicy: current.outputPolicy,
      ));
      _previewTimer?.cancel();
      _previewTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _previewing = null);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _previewing = null);
        _show(e.toString(), error: true);
      }
    }
  }

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _message = null;
    });
    try {
      final sound = await _custom.importFromDevice();
      if (sound != null) {
        await _select(sound.id);
        _show('“${sound.name}” imported and selected.');
      }
    } on CustomSoundException catch (e) {
      _show(e.message, error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _rename(CustomSound sound) async {
    final controller = TextEditingController(text: sound.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Rename sound'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Sound name'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _custom.rename(sound.id, name);
    setState(() {});
  }

  Future<void> _delete(CustomSound sound) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete sound?'),
        content: Text(
            '“${sound.name}” will be removed from Vokey. The original file on your phone is not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VokeyTokens.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _custom.delete(sound.id);
    await _alerts.ensureValidSelection();
    setState(() => _selected = _alerts.read().soundId);
  }

  Future<void> _restoreDefault() async {
    await _select(AlertSettingsRepository.defaultSoundId);
    _show('Default sound restored.');
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Library'),
        actions: [
          TextButton(
              onPressed: _restoreDefault, child: const Text('Restore default')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search sounds…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 14),
          PillSegments<String>(
            options: _categories,
            value: _category,
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          if (_message != null) ...[
            NoticeBanner(
              message: _message!,
              color: _messageIsError ? VokeyTokens.error : VokeyTokens.success,
              icon: _messageIsError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              onDismiss: () => setState(() => _message = null),
            ),
            const SizedBox(height: 14),
          ],
          if (entries.isEmpty)
            EmptyState(
              icon: Icons.library_music_outlined,
              title: _category == 'mine' && _query.isEmpty
                  ? 'No sounds of your own yet'
                  : 'No matching sounds',
              message: _category == 'mine' && _query.isEmpty
                  ? 'Import an MP3, M4A, OGG, WAV or FLAC file (up to 10 MB and 2 minutes).'
                  : 'Try another search.',
            )
          else
            for (final e in entries) _soundRow(e),
          const SizedBox(height: 10),
          GradientButton(
            label: _importing ? 'Importing…' : 'Import sound',
            icon: Icons.add_rounded,
            onPressed: _importing ? null : _import,
          ),
          const SizedBox(height: 12),
          const Text(
            'Imported sounds are copied into Vokey’s private storage — no access to your other files is '
            'needed. Built-in tones are generated on the phone.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: VokeyTokens.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _soundRow(_Entry e) {
    final selected = e.id == _selected;
    final playing = _previewing == e.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonCard(
        glow: selected ? VokeyTokens.success : null,
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        onTap: () => _select(e.id),
        child: Row(
          children: [
            IconButton(
              tooltip: playing ? 'Stop preview' : 'Preview ${e.name}',
              onPressed: () => _preview(e.id),
              icon: Icon(
                playing
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded,
                color:
                    e.custom == null ? VokeyTokens.cyan : VokeyTokens.magenta,
                size: 34,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    selected ? 'Selected for alerts' : e.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? VokeyTokens.success : VokeyTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? VokeyTokens.success : VokeyTokens.muted,
            ),
            if (e.custom != null)
              PopupMenuButton<String>(
                tooltip: 'Sound options',
                onSelected: (a) =>
                    a == 'rename' ? _rename(e.custom!) : _delete(e.custom!),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
