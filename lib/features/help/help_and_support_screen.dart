import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';
import '../alert_studio/alert_studio_screen.dart';
import '../battery_centre/battery_centre_screen.dart';
import '../permissions/permission_centre_screen.dart';
import '../voice_commands/voice_commands_screen.dart';
import '../voice_lock/voice_screen_lock_screen.dart';

class HelpAndSupportScreen extends StatelessWidget {
  const HelpAndSupportScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: VoiceMateApp.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need a hand?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                'These steps explain how to set up the finder and resolve common Android issues.',
                style: TextStyle(color: VoiceMateApp.muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _HelpSection(
          title: 'Start phone finder',
          body: 'Open Home and tap Start clap finder. Accept the microphone disclosure and grant microphone and notification permissions. Android keeps a foreground notification visible while the finder is active. Tap Stop in the app or notification to end monitoring.',
        ),
        const _HelpSection(
          title: 'Claps or whistles are not detected',
          body: 'Make sure monitoring is active and the microphone permission is allowed. Try a clear clap close to the phone in a quiet room. A steady whistle-like tone is detected by its frequency and duration; electronic beeps can sometimes resemble whistles. Phone cases, microphone placement, background noise and device audio processing affect detection.',
        ),
        const _HelpSection(
          title: 'Use flashlight alerts',
          body: 'Enable Flashlight pulses in Alert Studio. VoiceMate will request Camera permission because Android protects torch control with that permission on supported versions. The phone must have a working rear LED. If another app is using the camera, Android may temporarily make the torch unavailable.',
        ),
        const _HelpSection(
          title: 'Set up offline voice commands',
          body: 'Open Offline Voice Commands and download the English (US) model while connected to the internet. After the model is installed, voice recognition works on-device. Voice commands are active only while finder monitoring is running and the voice switch is enabled. Supported phrases are shown on that screen.',
        ),
        const _HelpSection(
          title: 'Background monitoring stops',
          body: 'Android and some phone manufacturers restrict background microphone services and battery use. Start monitoring while VoiceMate is open. Check Android app notifications, microphone permission and your manufacturer battery settings. VoiceMate does not silently restart monitoring after a force-stop or device reboot.',
        ),
        const _HelpSection(
          title: 'Voice Screen Lock',
          body: 'The lock shortcut needs explicit Device Admin activation in Android. It only locks the phone; unlocking still uses the normal PIN, pattern, password or biometrics. Do not activate Device Admin unless you understand this permission.',
        ),
        const SizedBox(height: 20),
        const Text('QUICK SETTINGS', style: TextStyle(
          color: VoiceMateApp.cyan,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 8),
        _HelpLink(
          icon: Icons.verified_user_outlined,
          title: 'Permissions Centre',
          subtitle: 'Check microphone, camera and notifications',
          builder: (_) => const PermissionCentreScreen(),
        ),
        _HelpLink(
          icon: Icons.tune_rounded,
          title: 'Alert Studio',
          subtitle: 'Sound, vibration and flashlight patterns',
          builder: (_) => const AlertStudioScreen(),
        ),
        _HelpLink(
          icon: Icons.record_voice_over_rounded,
          title: 'Offline Voice Commands',
          subtitle: 'Install the model and configure commands',
          builder: (_) => const VoiceCommandsScreen(),
        ),
        _HelpLink(
          icon: Icons.phonelink_lock_rounded,
          title: 'Voice Screen Lock',
          subtitle: 'Manage the optional lock-only permission',
          builder: (_) => const VoiceScreenLockScreen(),
        ),
        _HelpLink(
          icon: Icons.battery_charging_full_rounded,
          title: 'Battery & Performance',
          subtitle: 'Read the device battery and power status',
          builder: (_) => const BatteryCentreScreen(),
        ),
        const SizedBox(height: 16),
        const Text(
          'For account or privacy requests, use the developer contact published on the VoiceMate store listing once the app is released.',
          style: TextStyle(color: VoiceMateApp.muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(body, style: const TextStyle(
            color: VoiceMateApp.muted, height: 1.5)),
        ),
      ],
    ),
  );
}

class _HelpLink extends StatelessWidget {
  const _HelpLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: VoiceMateApp.cyan),
      title: Text(title),
      subtitle: Text(subtitle,
        style: const TextStyle(color: VoiceMateApp.muted)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: builder),
      ),
    ),
  );
}
