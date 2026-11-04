import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/history_repository.dart';
import '../../services/admob_service.dart';
import '../battery_centre/battery_centre_screen.dart';
import '../alert_studio/alert_studio_screen.dart';
import '../sound_library/sound_library_screen.dart';
import '../permissions/permission_centre_screen.dart';
import '../voice_lock/voice_screen_lock_screen.dart';
import '../voice_commands/voice_commands_screen.dart';
import '../privacy/privacy_policy_screen.dart';
import '../help/help_and_support_screen.dart';
import '../help/about_help_screen.dart';

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
              _section('DEVICE'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.battery_charging_full_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Battery & performance'),
                subtitle: const Text(
                  'Live charge, battery health and power status'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BatteryCentreScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section('FINDER ALERTS'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Alert Studio'),
                subtitle: const Text(
                  'Configure volume, duration, repeat and vibration'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlertStudioScreen(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.library_music_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Sound Library'),
                subtitle: const Text('Choose and preview built-in alert tones'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SoundLibraryScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section('VOICE CONTROL'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Offline Voice Commands'),
                subtitle: const Text(
                  'Install the local English model and set voice actions'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const VoiceCommandsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section('OPTIONAL SECURITY'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phonelink_lock_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Voice Screen Lock'),
                subtitle: const Text(
                  'Activate a lock-only device shortcut'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const VoiceScreenLockScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section('APP PERMISSIONS'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined,
                  color: VoiceMateApp.cyan),
                title: const Text('Permissions Centre'),
                subtitle: const Text(
                  'Check microphone and notification access'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PermissionCentreScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section('PRIVACY & DATA'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined,
                  color: VoiceMateApp.cyan),
                title: const Text('Microphone privacy'),
                subtitle: const Text(
                  'Finder monitoring uses the microphone only after you accept the disclosure, tap Start and grant the required permissions. Audio is processed in memory and is not stored or uploaded by VoiceMate.'),
                onTap: () => _showPrivacy(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.policy_outlined,
                  color: VoiceMateApp.cyan),
                title: const Text('Privacy Policy'),
                subtitle: const Text('How VoiceMate handles audio and local data'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: AdMobService.instance,
                builder: (context, _) =>
                    AdMobService.instance.privacyOptionsRequired
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.tune_rounded,
                              color: VoiceMateApp.cyan),
                            title: const Text('Advertising privacy choices'),
                            subtitle: const Text(
                              'Review or change Google consent choices'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _manageAdPrivacy(context),
                          )
                        : const SizedBox.shrink(),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline, color: VoiceMateApp.cyan),
                title: const Text('About & Help'),
                subtitle: const Text('Feature guide and troubleshooting'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutHelpScreen(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline_rounded,
                  color: VoiceMateApp.cyan),
                title: const Text('Help & Support'),
                subtitle: const Text('Setup, permissions and troubleshooting'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HelpAndSupportScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: VoiceMateApp.surface,
                  borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  'Current capabilities: foreground clap-and-whistle finder, persistent Stop notification, configurable sound/vibration/flashlight alerts, local event history, battery and memory readings, permission controls, offline English voice commands after model setup, lock-only shortcut, and consent-gated Home banner ads. Real AdMob production IDs and physical-device validation are still required before release.',
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

  Future<void> _manageAdPrivacy(BuildContext context) async {
    try {
      await AdMobService.instance.showPrivacyOptions();
      if (!context.mounted) return;
      final message = AdMobService.instance.privacyOptionsRequired
          ? 'Google privacy options are still required. You can reopen this page to review them.'
          : 'No additional Google privacy choices are required for this session.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open privacy choices: $error')),
      );
    }
  }

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Microphone privacy'),
        content: const SingleChildScrollView(child: Text(
          'VoiceMate requests microphone access only after you explicitly choose to start a supported finder feature. When offline voice commands are enabled, speech is recognised locally with the downloaded English (US) model. Audio samples and recognised phrases are processed in memory; VoiceMate does not save raw recordings or transcripts or upload microphone audio. The active service is indicated by an Android notification with a Stop action. Local history stores event types, timestamps and numeric metadata only.')),
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
