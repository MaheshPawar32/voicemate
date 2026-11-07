import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/vokey_app.dart';
import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/alert_settings_repository.dart';
import '../../services/finder_monitoring_service.dart';
import '../../services/monitoring_controller.dart';
import '../sound_library/sound_library_screen.dart';
import '../../services/telemetry_service.dart';

/// Alert Studio (reference board): Sound / Vibration / Flashlight tabs.
class AlertStudioScreen extends StatefulWidget {
  const AlertStudioScreen({super.key});

  @override
  State<AlertStudioScreen> createState() => _AlertStudioScreenState();
}

class _AlertStudioScreenState extends State<AlertStudioScreen> {
  late final AlertSettingsRepository _repo = AlertSettingsRepository(
    Hive.box<dynamic>(AppStartupState.settingsBoxName),
  );
  late AlertPreferences _p = _repo.read();
  final _finder = FinderMonitoringService();
  String _tab = 'sound';
  bool _previewing = false;
  Timer? _previewTimer;
  String? _error;
  StreamSubscription<FinderMonitoringEvent>? _events;

  static const _tabs = {
    'sound': 'Sound',
    'vibration': 'Vibration',
    'flash': 'Flashlight'
  };

  @override
  void initState() {
    super.initState();
    _events = _finder.events.listen((e) {
      if (e.type == 'alert_sound_unavailable' && mounted) {
        setState(() => _error = soundUnavailableMessage(e.reason));
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _events?.cancel();
    _previewTimer?.cancel();
    if (_previewing) _repo.stopPreview();
    super.dispose();
  }

  Future<void> _set(AlertPreferences next) async {
    setState(() {
      _p = next;
      _error = null;
    });
    await _repo.saveAll(next);
    _p = _repo.read(); // resolves custom sound file
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    await _repo.stopPreview();
    if (mounted) setState(() => _previewing = false);
  }

  Future<void> _preview() async {
    if (_previewing) return _stopPreview();
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      if (_p.flashlightEnabled && !await _finder.requestCameraPermission()) {
        throw const FinderMonitoringException(
          'Camera permission is needed to preview the flashlight. Sound and vibration still preview with flashlight off.',
        );
      }
      await _repo.preview(_p);
      TelemetryService.instance.log('alert_previewed', {
        'output': _p.outputPolicy,
        'ramp': _p.volumeRampEnabled,
        'custom_sound': _p.soundId.startsWith('custom:'),
        'flash': _p.flashlightEnabled,
      });
      _previewTimer = Timer(Duration(seconds: _p.durationSeconds), () {
        if (mounted) setState(() => _previewing = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SoundLibraryScreen()),
    );
    if (mounted) setState(() => _p = _repo.read());
  }

  Future<void> _pickOutput() async {
    final picked = await showChoiceSheet<String>(
      context,
      title: 'Play alerts on',
      options: AlertSettingsRepository.outputPolicies,
      current: _p.outputPolicy,
    );
    if (picked != null) await _set(_p.copyWith(outputPolicy: picked));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alert Studio')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            PillSegments<String>(
              options: _tabs,
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 8),
            ...switch (_tab) {
              'vibration' => _vibrationTab(),
              'flash' => _flashTab(),
              _ => _soundTab(),
            },
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null)),
            ],
            const SizedBox(height: 22),
            if (_previewing)
              DangerButton(label: 'Stop preview', onPressed: _stopPreview)
            else
              GradientButton(
                label: 'Preview alert',
                icon: Icons.play_arrow_rounded,
                onPressed: _preview,
              ),
            const SizedBox(height: 12),
            const Text(
              'Saved settings are used the next time the finder starts. Vokey controls its own alert '
              'level and never changes your phone’s volume settings — if the phone’s alarm volume is '
              'off, alerts will be quiet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: VokeyTokens.muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );

  List<Widget> _soundTab() => [
        const SectionLabel('Sound'),
        ToggleRow(
          icon: Icons.volume_up_rounded,
          title: 'Play a sound',
          value: _p.soundEnabled,
          onChanged: (v) => _set(_p.copyWith(soundEnabled: v)),
        ),
        SettingRow(
          icon: Icons.library_music_rounded,
          iconColor: VokeyTokens.magenta,
          title: 'Alert sound',
          subtitle: _repo.soundName(_p.soundId),
          onTap: _openLibrary,
        ),
        NeonCard(
          child: LabeledSlider(
            label: _p.volumeRampEnabled ? 'Maximum volume' : 'Volume',
            value: _p.volume.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            display: '${_p.volume}%',
            onChanged: (v) =>
                setState(() => _p = _p.copyWith(volume: v.round())),
          ),
        ),
        const SizedBox(height: 14),
        ToggleRow(
          icon: Icons.trending_up_rounded,
          title: 'Gradually rising volume',
          subtitle: _p.volumeRampEnabled
              ? 'From ${_p.rampStartPercent}% to full over ${_p.rampSeconds} s'
              : 'Starts at full volume',
          value: _p.volumeRampEnabled,
          onChanged: (v) => _set(_p.copyWith(volumeRampEnabled: v)),
        ),
        if (_p.volumeRampEnabled) ...[
          NeonCard(
            child: Column(
              children: [
                LabeledSlider(
                  label: 'Start at',
                  value: _p.rampStartPercent.toDouble(),
                  min: 0,
                  max: 90,
                  divisions: 9,
                  display: '${_p.rampStartPercent}% of maximum',
                  onChanged: (v) => setState(
                      () => _p = _p.copyWith(rampStartPercent: v.round())),
                ),
                const SizedBox(height: 6),
                LabeledSlider(
                  label: 'Reach full volume in',
                  value: _p.rampSeconds.toDouble(),
                  min: 2,
                  max: 30,
                  divisions: 14,
                  display: '${_p.rampSeconds} s',
                  onChanged: (v) =>
                      setState(() => _p = _p.copyWith(rampSeconds: v.round())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        SettingRow(
          icon: Icons.headphones_rounded,
          title: 'Output',
          subtitle: switch (_p.outputPolicy) {
            'speaker' => 'Always the phone speaker',
            'headphones' => 'Only when headphones are connected',
            _ => 'Android decides (usually the speaker)',
          },
          trailing: Text(
            AlertSettingsRepository.outputPolicies[_p.outputPolicy]!
                .split(' ')
                .first,
            style: const TextStyle(color: VokeyTokens.muted),
          ),
          onTap: _pickOutput,
        ),
        if (_p.outputPolicy == 'headphones')
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: NoticeBanner(
              color: VokeyTokens.warning,
              message:
                  'With Headphones only, a lost phone with no headphones attached will stay silent (vibration and flashlight still work).',
            ),
          ),
        NeonCard(
          child: Column(
            children: [
              LabeledSlider(
                label: 'Alert duration',
                value: _p.durationSeconds.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                display: '${_p.durationSeconds} s',
                onChanged: (v) => setState(
                    () => _p = _p.copyWith(durationSeconds: v.round())),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat during alert'),
                value: _p.repeatEnabled,
                onChanged: (v) => _set(_p.copyWith(repeatEnabled: v)),
              ),
            ],
          ),
        ),
        // Sliders update state while dragging; persist once released.
        _SaveOnIdle(onSave: () => _repo.saveAll(_p), token: _p),
      ];

  List<Widget> _vibrationTab() => [
        const SectionLabel('Vibration'),
        ToggleRow(
          icon: Icons.vibration_rounded,
          title: 'Vibrate',
          subtitle: 'Double pulse, repeated while the alert plays',
          value: _p.vibrationEnabled,
          onChanged: (v) => _set(_p.copyWith(vibrationEnabled: v)),
        ),
      ];

  List<Widget> _flashTab() => [
        const SectionLabel('Flashlight'),
        ToggleRow(
          icon: Icons.flashlight_on_rounded,
          title: 'Flash the rear light',
          subtitle: 'Needs camera permission and a rear flash',
          value: _p.flashlightEnabled,
          onChanged: (v) => _set(_p.copyWith(flashlightEnabled: v)),
        ),
        if (_p.flashlightEnabled) ...[
          const SectionLabel('Pattern'),
          PillSegments<String>(
            options: const {
              'single': 'Pulse',
              'double': 'Double',
              'sos': 'SOS'
            },
            value: _p.flashPattern,
            onChanged: (v) => _set(_p.copyWith(flashPattern: v)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Android may block the flashlight while another app uses the camera. The light always turns off when the alert stops.',
            style: TextStyle(
                color: VokeyTokens.muted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ];
}

/// Debounced save for slider drags (avoids a disk write per frame).
class _SaveOnIdle extends StatefulWidget {
  const _SaveOnIdle({required this.onSave, required this.token});
  final Future<void> Function() onSave;
  final Object token;

  @override
  State<_SaveOnIdle> createState() => _SaveOnIdleState();
}

class _SaveOnIdleState extends State<_SaveOnIdle> {
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _SaveOnIdle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.token, widget.token)) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 400), widget.onSave);
    }
  }

  @override
  void dispose() {
    if (_timer?.isActive ?? false) widget.onSave();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
