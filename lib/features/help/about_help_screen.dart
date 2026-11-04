import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';

class AboutHelpScreen extends StatelessWidget {
  const AboutHelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About & Help')),
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
            border: Border.all(
              color: VoiceMateApp.cyan.withValues(alpha: .2)),
          ),
          child: const Column(
            children: [
              Icon(Icons.graphic_eq_rounded,
                size: 50, color: VoiceMateApp.cyan),
              SizedBox(height: 12),
              Text('VoiceMate', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Your phone listens. Your phone responds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VoiceMateApp.muted)),
              SizedBox(height: 10),
              Text('Android · Version 0.1.0',
                style: TextStyle(
                  color: VoiceMateApp.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _HelpSection(
          title: 'Find your phone with a clap or whistle',
          body: 'Open Home and tap Start clap finder. Accept the microphone disclosure and Android permissions. Keep the ongoing VoiceMate notification visible. Clap or make a steady whistle-like tone near the phone. When a supported signal is detected, VoiceMate plays the alert configured in Alert Studio. Tap Stop in the app or in the notification to finish.',
        ),
        const _HelpSection(
          title: 'Use offline voice commands',
          body: 'Open Settings → Offline Voice Commands and download the English (US) model. This needs an internet connection once; afterwards, supported voice recognition runs on the phone. Enable voice commands and start finder monitoring. Say “Find my phone”, “Where are you?”, or “Hello VoiceMate” to play the finder alert. Say “Stop listening” to stop monitoring.',
        ),
        const _HelpSection(
          title: 'Voice screen lock',
          body: 'Open Settings → Voice Screen Lock and activate the optional Android Device Admin permission. Android displays its own confirmation. VoiceMate uses only the lock action. It cannot unlock the device. You can remove Device Admin in Android security settings.',
        ),
        const _HelpSection(
          title: 'The finder stopped in the background',
          body: 'Android and phone manufacturers can restrict microphone foreground services or stop background work to save power. Check Android microphone and notification permissions, make sure the ongoing notification is allowed, and review your manufacturer battery settings. VoiceMate does not silently add itself to battery-optimization exemptions.',
        ),
        const _HelpSection(
          title: 'A clap or whistle is not detected',
          body: 'Try the foreground diagnostic from Home in a quiet room. Keep the microphone opening uncovered and test at several distances. Television audio, beeps, music and other sustained tones can resemble a whistle. Detection sensitivity depends on the phone microphone and environment; do not rely on it as a guaranteed security or emergency feature.',
        ),
        const _HelpSection(
          title: 'No sound or vibration',
          body: 'Open Settings → Alert Studio. Check that sound or vibration is enabled, raise the alert volume and preview the selected built-in tone. Also check Android alarm volume, Do Not Disturb and the phone’s vibration settings.',
        ),
        const _HelpSection(
          title: 'Local data',
          body: 'Event history and settings stay in VoiceMate app storage. Clear event history in Settings. Clearing Android app storage or uninstalling removes the saved data and any downloaded voice model.',
        ),
        const SizedBox(height: 10),
        const Text(
          'VoiceMate is a convenience utility. Detection is not guaranteed in every environment or on every Android device.',
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(body, style: const TextStyle(
          color: VoiceMateApp.muted, height: 1.55)),
      ],
    ),
  );
}
