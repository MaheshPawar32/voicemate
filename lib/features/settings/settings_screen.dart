import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/history_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<dynamic>('voicemate_settings');
    final history = HistoryRepository(box);
    return SafeArea(
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: box.listenable(keys: [HistoryRepository.storageKey]),
        builder: (context, _, __) {
          final eventCount = history.readAll().length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            children: [
              const Text('Settings', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Privacy and local app data.',
                style: TextStyle(color: VoiceMateApp.muted)),
              const SizedBox(height: 25),
              _section('PRIVACY & DATA'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined,
                  color: VoiceMateApp.cyan),
                title: const Text('Microphone privacy'),
                subtitle: const Text(
                  'The diagnostic uses the microphone only while the test is open. Audio is processed in memory.'),
                onTap: () => _showPrivacy(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Clear detection history'),
                subtitle: Text('$eventCount saved event(s) on this device'),
                enabled: eventCount > 0,
                onTap: eventCount == 0
                    ? null
                    : () => _confirmClear(context, history),
              ),
              const SizedBox(height: 18),
              _section('ABOUT'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline, color: VoiceMateApp.cyan),
                title: Text('VoiceMate'),
                subtitle: Text('Version 0.1.0 · Android'),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: VoiceMateApp.surface,
                  borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  'Available in this build: foreground clap-and-whistle monitoring, a persistent Android Stop notification, basic sound/vibration finder alerts, foreground diagnostics and local event history. Offline voice commands, voice screen lock, custom alert studio, sound library, flashlight controls, battery centre and AdMob/consent integration are still under development.',
                  style: TextStyle(
                    color: VoiceMateApp.muted, fontSize: 12, height: 1.5)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(
      color: VoiceMateApp.cyan, fontSize: 11,
      letterSpacing: 1.5, fontWeight: FontWeight.w800)),
  );

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Microphone privacy'),
        content: const SingleChildScrollView(child: Text(
          'VoiceMate requests microphone access only when you start the foreground clap diagnostic. Audio samples are processed in memory to calculate signal levels and clap events. The app does not save or upload raw audio. Detection history stores event timestamps and numeric metadata only. You can stop the test at any time from its screen.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context, HistoryRepository history,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete local history?'),
        content: const Text(
          'All saved detection events will be permanently removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await history.clear();
  }
}
