import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';
import '../../services/permission_centre_service.dart';

class PermissionCentreScreen extends StatefulWidget {
  const PermissionCentreScreen({super.key});

  @override
  State<PermissionCentreScreen> createState() => _PermissionCentreScreenState();
}

class _PermissionCentreScreenState extends State<PermissionCentreScreen> {
  final PermissionCentreService _service = PermissionCentreService();
  late Future<PermissionStatusSnapshot> _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = _service.readStatus();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = _service.readStatus();
    });
    try {
      await _status;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestMicrophone() async {
    await _perform(_service.requestMicrophone);
  }

  Future<void> _requestNotifications() async {
    await _perform(_service.requestNotifications);
  }

  Future<void> _openSettings() async {
    try {
      await _service.openAppSettings();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _perform(Future<bool> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Permissions Centre'),
      actions: [
        IconButton(
          tooltip: 'Refresh permissions',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<PermissionStatusSnapshot>(
      future: _status,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!state.hasData) {
          return _ErrorState(
            message: _error ?? state.error?.toString() ??
                'Permission status is unavailable.',
            onRetry: _refresh,
          );
        }
        final permission = state.data!;
        final notificationsReady = permission.monitoringNotificationReady;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: VoiceMateApp.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'VoiceMate asks for permissions only when a feature needs them. Microphone access is used for clap, whistle and supported offline voice detection. The monitoring notification keeps the active microphone service visible and provides a Stop action.',
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 22),
            _PermissionTile(
              icon: Icons.mic_none_rounded,
              title: 'Microphone',
              description: 'Required for clap, whistle and voice detection.',
              granted: permission.microphoneGranted,
              grantedLabel: 'Allowed',
              deniedLabel: 'Not allowed',
              actionLabel: 'Allow microphone',
              onAction: _busy ? null : _requestMicrophone,
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              description: permission.apiLevel >= 33
                  ? 'Required by VoiceMate to show the active-monitoring notification and Stop action.'
                  : 'App notification visibility for monitoring controls.',
              granted: notificationsReady,
              grantedLabel: 'Enabled',
              deniedLabel: 'Disabled',
              actionLabel: 'Allow notifications',
              onAction: _busy ? null : _requestNotifications,
            ),
            const SizedBox(height: 22),
            const Text('APP SETTINGS', style: TextStyle(
              color: VoiceMateApp.cyan,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_outlined,
                  color: VoiceMateApp.cyan),
                title: const Text('Open Android app settings'),
                subtitle: const Text(
                  'Manage permissions and notification controls directly in Android.'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: _openSettings,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(
                color: Color(0xFFFFA7B2))),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        );
      },
    ),
  );
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.grantedLabel,
    required this.deniedLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final String grantedLabel;
  final String deniedLabel;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: VoiceMateApp.cyan, size: 26),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16))),
            Icon(
              granted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: granted
                ? const Color(0xFF38D99A) : const Color(0xFFFFBE55),
            ),
            const SizedBox(width: 6),
            Text(
              granted ? grantedLabel : deniedLabel,
              style: TextStyle(
                color: granted
                  ? const Color(0xFF38D99A) : const Color(0xFFFFBE55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(
            color: VoiceMateApp.muted, height: 1.4)),
          if (!granted) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined,
            size: 48, color: VoiceMateApp.cyan),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
