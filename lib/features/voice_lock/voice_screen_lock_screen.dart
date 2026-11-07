import 'package:flutter/material.dart';

import '../../app/vokey_app.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/voice_lock_service.dart';
import '../../services/voice_settings_repository.dart';

class VoiceScreenLockScreen extends StatefulWidget {
  const VoiceScreenLockScreen({super.key});

  @override
  State<VoiceScreenLockScreen> createState() => _VoiceScreenLockScreenState();
}

class _VoiceScreenLockScreenState extends State<VoiceScreenLockScreen>
    with WidgetsBindingObserver {
  final VoiceLockService _service = VoiceLockService();
  bool? _adminActive;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final active = await _service.isAdminActive();
      if (mounted) {
        setState(() {
          _adminActive = active;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.requestActivation();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Turn off screen-lock permission?'),
        content: const Text(
          'The “Lock my phone” shortcut and voice lock stop working until you activate it again. Turn this off before uninstalling Vokey.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.deactivate();
      await VoiceSettingsRepository(
              Hive.box<dynamic>(AppStartupState.settingsBoxName))
          .setLockCommandEnabled(false);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _lock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lock this phone now?'),
        content: const Text(
          'Vokey will ask Android to turn off the screen and lock the device. Unlocking still requires your normal PIN, pattern, password or biometrics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lock phone'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.lockNow();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Voice Screen Lock')),
        body: ListView(
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
                border: Border.all(color: VokeyApp.cyan.withValues(alpha: .22)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.phonelink_lock_rounded,
                      size: 58, color: VokeyApp.cyan),
                  SizedBox(height: 15),
                  Text('Lock only. Never unlock.',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                    'This optional shortcut uses Android Device Admin with the force-lock policy. Vokey cannot unlock the phone, read your PIN or bypass biometrics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VokeyApp.muted, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: Icon(
                  _adminActive == true
                      ? Icons.verified_user_rounded
                      : Icons.admin_panel_settings_outlined,
                  color: _adminActive == true
                      ? const Color(0xFF38D99A)
                      : const Color(0xFFFFBE55),
                ),
                title: const Text('Device Admin permission'),
                subtitle: Text(_adminActive == true
                    ? 'Activated on this device'
                    : (_adminActive == false
                        ? 'Not activated'
                        : 'Checking permission status…')),
                trailing: IconButton(
                  tooltip: 'Refresh status',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_adminActive == true)
              FilledButton.icon(
                onPressed: _busy ? null : _lock,
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Lock phone now'),
                style: FilledButton.styleFrom(
                  backgroundColor: VokeyApp.cyan,
                  foregroundColor: const Color(0xFF06111D),
                  minimumSize: const Size.fromHeight(54),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy || _adminActive == null ? null : _activate,
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('Activate lock permission'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            if (_adminActive == true) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _deactivate,
                icon: const Icon(Icons.remove_moderator_outlined),
                label: const Text('Turn off screen-lock permission'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Turn this permission off here (or in Android Settings → Security → Device admin apps) before uninstalling Vokey. Vokey does not use Accessibility services or any unlock automation.',
              style:
                  TextStyle(color: VokeyApp.muted, height: 1.5, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFFFA7B2))),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
}
