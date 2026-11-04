import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/finder_monitoring_service.dart';
import '../../services/voice_lock_service.dart';
import '../../services/voice_settings_repository.dart';
import '../voice_lock/voice_screen_lock_screen.dart';

class VoiceCommandsScreen extends StatefulWidget {
  const VoiceCommandsScreen({super.key});

  @override
  State<VoiceCommandsScreen> createState() => _VoiceCommandsScreenState();
}

class _VoiceCommandsScreenState extends State<VoiceCommandsScreen>
    with WidgetsBindingObserver {
  final FinderMonitoringService _finder = FinderMonitoringService();
  final VoiceLockService _lock = VoiceLockService();
  late final VoiceSettingsRepository _settings;
  StreamSubscription<FinderMonitoringEvent>? _eventSubscription;
  bool _modelInstalled = false;
  bool _voiceEnabled = false;
  bool _lockCommandEnabled = false;
  bool _deviceAdminActive = false;
  bool _loading = true;
  bool _installing = false;
  double? _downloadProgress;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = VoiceSettingsRepository(
      Hive.box<dynamic>('voicemate_settings'),
    );
    final saved = _settings.read();
    _voiceEnabled = saved.enabled;
    _lockCommandEnabled = saved.lockCommandEnabled;
    _eventSubscription = _finder.events.listen(_handleEvent,
      onError: (Object error) {
        if (mounted) setState(() => _error = error.toString());
      });
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  void _handleEvent(FinderMonitoringEvent event) {
    if (!mounted) return;
    if (event.type == 'voice_model_progress') {
      final progress = event.totalBytes > 0
          ? (event.downloadedBytes / event.totalBytes).clamp(0.0, 1.0)
          : null;
      setState(() => _downloadProgress = progress);
    } else if (event.type == 'voice_model_ready') {
      setState(() {
        _modelInstalled = true;
        _installing = false;
        _downloadProgress = 1;
        _error = null;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<Object>([
        _finder.isVoiceModelInstalled(),
        _lock.isAdminActive(),
      ]);
      if (!mounted) return;
      setState(() {
        _modelInstalled = results[0] as bool;
        _deviceAdminActive = results[1] as bool;
        _loading = false;
        if (!_modelInstalled) {
          _voiceEnabled = false;
        }
        if (!_deviceAdminActive) {
          _lockCommandEnabled = false;
        }
      });
      if (!_modelInstalled && _voiceEnabled) {
        await _settings.setEnabled(false);
        if (mounted) setState(() => _voiceEnabled = false);
      }
      if (!_deviceAdminActive && _lockCommandEnabled) {
        await _settings.setLockCommandEnabled(false);
        if (mounted) setState(() => _lockCommandEnabled = false);
      }
    } catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _downloadModel() async {
    if (_installing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Download offline English model?'),
        content: const Text(
          'VoiceMate needs a one-time download of about 40 MB. The model is stored in this app’s private storage and used on this phone. After setup, voice commands work without internet. VoiceMate verifies the downloaded model before installation.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Download model'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _installing = true;
      _downloadProgress = null;
      _error = null;
    });
    try {
      await _finder.installVoiceModel();
      if (mounted) {
        setState(() {
          _modelInstalled = true;
          _installing = false;
          _downloadProgress = 1;
        });
      }
    } catch (error) {
      if (mounted) setState(() {
        _installing = false;
        _downloadProgress = null;
        _error = error.toString();
      });
    }
  }

  Future<void> _setVoiceEnabled(bool value) async {
    if (value && !_modelInstalled) return;
    await _settings.setEnabled(value);
    if (mounted) setState(() => _voiceEnabled = value);
  }

  Future<void> _setLockCommand(bool value) async {
    if (value && !_deviceAdminActive) return;
    await _settings.setLockCommandEnabled(value);
    if (mounted) setState(() => _lockCommandEnabled = value);
  }

  Future<void> _openLockSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VoiceScreenLockScreen(),
      ),
    );
    await _refresh();
  }

  String _progressText() {
    if (_downloadProgress == null) return 'Downloading and verifying model…';
    return 'Downloading model · ${(_downloadProgress! * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Voice Commands')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF19335A), Color(0xFF111D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: VoiceMateApp.cyan.withValues(alpha: .22),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.graphic_eq_rounded,
                      size: 54, color: VoiceMateApp.cyan),
                    SizedBox(height: 13),
                    Text('On-device voice recognition',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 7),
                    Text(
                      'Speech is recognised on your phone using a local model. No cloud speech service or transcript upload is used.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VoiceMateApp.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('VOICE MODEL', style: TextStyle(
                color: VoiceMateApp.cyan,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(
                    _modelInstalled
                        ? Icons.check_circle_rounded
                        : Icons.cloud_download_outlined,
                    color: _modelInstalled
                        ? const Color(0xFF38D99A)
                        : VoiceMateApp.cyan,
                  ),
                  title: const Text('English (US) · Small model'),
                  subtitle: Text(_modelInstalled
                      ? 'Installed · Works offline'
                      : 'Not installed · One-time download ~40 MB'),
                  trailing: _modelInstalled
                      ? const Text('READY',
                          style: TextStyle(
                            color: Color(0xFF38D99A),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ))
                      : null,
                ),
              ),
              if (_installing) ...[
                const SizedBox(height: 12),
                Text(_progressText(),
                    style: const TextStyle(color: VoiceMateApp.muted)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _downloadProgress),
              ] else if (!_modelInstalled) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _downloadModel,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download offline model'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VoiceMateApp.cyan,
                    foregroundColor: const Color(0xFF06111D),
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const Text('VOICE CONTROL', style: TextStyle(
                color: VoiceMateApp.cyan,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              )),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable offline voice commands'),
                subtitle: Text(_modelInstalled
                    ? 'Commands are recognised while finder monitoring is active.'
                    : 'Install the voice model before enabling this feature.'),
                value: _voiceEnabled && _modelInstalled,
                activeThumbColor: VoiceMateApp.cyan,
                onChanged: !_modelInstalled || _installing
                    ? null
                    : _setVoiceEnabled,
              ),
              const SizedBox(height: 12),
              const Text('SUPPORTED COMMANDS', style: TextStyle(
                color: VoiceMateApp.muted,
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 8),
              const _CommandTile(
                phrase: '“Find my phone”',
                action: 'Plays your selected finder alert',
              ),
              const _CommandTile(
                phrase: '“Where are you?”',
                action: 'Plays your selected finder alert',
              ),
              const _CommandTile(
                phrase: '“Hello VoiceMate”',
                action: 'Plays your selected finder alert',
              ),
              const _CommandTile(
                phrase: '“Stop listening”',
                action: 'Stops background monitoring',
              ),
              const SizedBox(height: 18),
              const Text('OPTIONAL LOCK COMMAND', style: TextStyle(
                color: VoiceMateApp.cyan,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              )),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Allow voice to lock this phone'),
                      subtitle: Text(_deviceAdminActive
                          ? '“Lock my phone” uses Android Device Admin.'
                          : 'Activate the lock-only Device Admin permission first.'),
                      value: _lockCommandEnabled && _deviceAdminActive,
                      activeThumbColor: VoiceMateApp.cyan,
                      onChanged: !_deviceAdminActive || !_voiceEnabled
                          ? null
                          : _setLockCommand,
                    ),
                    if (!_deviceAdminActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: _openLockSetup,
                            child: const Text('Set up screen lock'),
                          ),
                        ),
                      ),
                    if (_lockCommandEnabled && _deviceAdminActive)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Supported phrase: “Lock my phone”',
                            style: TextStyle(
                              color: VoiceMateApp.muted, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: VoiceMateApp.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Voice commands listen only when you explicitly start finder monitoring and enable voice commands. The microphone runs under the visible Android foreground-service notification. Voice lock can only lock the screen; it cannot unlock the phone or bypass your PIN, password or biometrics.',
                  style: TextStyle(
                    color: VoiceMateApp.muted, height: 1.5, fontSize: 12),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(
                  color: Color(0xFFFFA7B2), height: 1.4)),
              ],
            ],
          ),
  );
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.phrase, required this.action});
  final String phrase;
  final String action;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.mic_none_rounded,
        color: VoiceMateApp.cyan),
      title: Text(phrase,
        style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(action,
        style: const TextStyle(color: VoiceMateApp.muted)),
    ),
  );
}
