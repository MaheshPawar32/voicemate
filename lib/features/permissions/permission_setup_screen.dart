import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/monitoring_controller.dart';
import '../../services/permission_centre_service.dart';
import '../finder/finder_start_flow.dart';
import '../voice_lock/voice_screen_lock_screen.dart';
import '../../services/telemetry_service.dart';

enum PermissionState { granted, notAsked, denied, blocked, unsupported }

/// Maps Android's answers to one UI state. Android reports
/// shouldShowRequestPermissionRationale == false both before the first ask
/// and after "Don't ask again", so we remember whether we asked.
PermissionState permissionStateFor({
  required bool granted,
  required bool asked,
  required bool rationale,
  bool supported = true,
}) {
  if (!supported) return PermissionState.unsupported;
  if (granted) return PermissionState.granted;
  if (!asked) return PermissionState.notAsked;
  return rationale ? PermissionState.denied : PermissionState.blocked;
}

/// "Set Up Vokey" (reference board) — shown once after onboarding. Each
/// permission is explained and requested only when the user taps it.
class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const doneKey = 'permission_setup_complete';

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  final _service = PermissionCentreService();
  PermissionStatusSnapshot? _status;
  String? _error;
  bool _busy = false;

  static const _askedMic = 'permission_asked_microphone';
  static const _askedNotif = 'permission_asked_notifications';
  static const _askedCamera = 'permission_asked_camera';

  Box<dynamic> get _box => MonitoringController.instance.box;

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

  /// Re-check after returning from Android Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await _service.readStatus();
      if (mounted) setState(() => _status = s);
    } on PermissionCentreException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool _asked(String key) => _box.get(key, defaultValue: false) == true;

  PermissionState get _mic => permissionStateFor(
        granted: _status?.microphoneGranted ?? false,
        asked: _asked(_askedMic),
        rationale: _status?.microphoneRationale ?? false,
      );

  PermissionState get _notif => permissionStateFor(
        granted: _status?.monitoringNotificationReady ?? false,
        asked: _asked(_askedNotif),
        rationale: _status?.notificationRationale ?? false,
      );

  PermissionState get _camera => permissionStateFor(
        granted: _status?.cameraGranted ?? false,
        asked: _asked(_askedCamera),
        rationale: _status?.cameraRationale ?? false,
        supported: _status?.hasFlash ?? true,
      );

  Future<void> _request(String which) async {
    if (_busy) return;
    final state = switch (which) {
      'mic' => _mic,
      'notif' => _notif,
      _ => _camera,
    };
    if (state == PermissionState.blocked) {
      await _service.openAppSettings();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // "asked" is stored only after Android answers: while a system dialog is
    // open, a resume-triggered refresh must not report the permission as
    // blocked (rationale is false until the first answer).
    try {
      switch (which) {
        case 'mic':
          // Prominent disclosure before the system dialog.
          if (!await FinderStartFlow.confirmDisclosure(context)) break;
          await _service.requestMicrophone();
          await _box.put(_askedMic, true);
        case 'notif':
          await _service.requestNotifications();
          await _box.put(_askedNotif, true);
        case 'camera':
          await _service.requestCamera();
          await _box.put(_askedCamera, true);
      }
    } on PermissionCentreException catch (e) {
      _error = e.message;
    } finally {
      _busy = false;
      await _refresh();
    }
  }

  Future<void> _allowAndContinue() async {
    if (_mic != PermissionState.granted && _mic != PermissionState.blocked) {
      await _request('mic');
    }
    if (!mounted) return;
    if (_notif != PermissionState.granted &&
        _notif != PermissionState.blocked) {
      await _request('notif');
    }
    await _finish();
  }

  Future<void> _finish() async {
    TelemetryService.instance.log('permission_setup_completed', {
      'microphone': _mic == PermissionState.granted,
      'notifications': _notif == PermissionState.granted,
      'camera': _camera == PermissionState.granted,
    });
    await _box.put(PermissionSetupScreen.doneKey, true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _status == null && _error == null;
    final requiredReady =
        _mic == PermissionState.granted && _notif == PermissionState.granted;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          children: [
            const Text(
              'Set Up Vokey',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow a few permissions for the best experience.\nYou can change these any time in Android Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VokeyTokens.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _PermissionRow(
                icon: Icons.mic_rounded,
                title: 'Microphone',
                subtitle: 'Detect claps, whistles and voice · required',
                state: _mic,
                onTap: () => _request('mic'),
              ),
              _PermissionRow(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                subtitle:
                    'Show listening status and the Stop button · required',
                state: _notif,
                onTap: () => _request('notif'),
              ),
              _PermissionRow(
                icon: Icons.flashlight_on_rounded,
                title: 'Camera (flashlight)',
                subtitle: 'Only to blink the flash during alerts · optional',
                state: _camera,
                onTap: () => _request('camera'),
              ),
              SettingRow(
                icon: Icons.admin_panel_settings_outlined,
                iconColor: VokeyTokens.violet,
                title: 'Device admin',
                subtitle: 'For the screen-lock shortcut · optional',
                trailing: _status?.deviceAdminActive == true
                    ? const StatusPill('Active')
                    : const Icon(Icons.chevron_right_rounded,
                        color: VokeyTokens.muted),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const VoiceScreenLockScreen(),
                  ));
                  await _refresh();
                },
              ),
            ],
            if (_mic == PermissionState.blocked ||
                _notif == PermissionState.blocked) ...[
              const SizedBox(height: 4),
              const NoticeBanner(
                color: VokeyTokens.warning,
                message:
                    'Android will not ask again for a blocked permission. Tap it to open Settings → Permissions and allow it there.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              NoticeBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null)),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: requiredReady ? 'Continue' : 'Allow & Continue',
              onPressed: _busy || loading
                  ? null
                  : (requiredReady ? _finish : _allowAndContinue),
            ),
            const SizedBox(height: 8),
            if (!requiredReady)
              TextButton(
                onPressed: _busy ? null : _finish,
                child: const Text('Skip for now',
                    style: TextStyle(color: VokeyTokens.muted)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final PermissionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trailing = switch (state) {
      PermissionState.granted =>
        const Icon(Icons.check_circle_rounded, color: VokeyTokens.success),
      PermissionState.unsupported =>
        const StatusPill('Not available', color: VokeyTokens.muted),
      PermissionState.blocked =>
        const StatusPill('Open settings', color: VokeyTokens.warning),
      PermissionState.denied =>
        const StatusPill('Denied', color: VokeyTokens.error),
      PermissionState.notAsked =>
        const StatusPill('Allow', color: VokeyTokens.cyan),
    };
    final tappable = state != PermissionState.granted &&
        state != PermissionState.unsupported;
    return Semantics(
      label: '$title: ${state.name}',
      child: SettingRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: tappable ? onTap : null,
      ),
    );
  }
}
